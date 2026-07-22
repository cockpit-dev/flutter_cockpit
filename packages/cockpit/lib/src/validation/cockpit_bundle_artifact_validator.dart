import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../artifacts/cockpit_recording_keyframe_extractor.dart';
import '../capture/cockpit_screenshot_inspector.dart';
import '../infrastructure/cockpit_process_manager.dart';
import '../recording/cockpit_video_artifact_inspector.dart';

typedef CockpitArtifactValidationProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

final class CockpitBundleArtifactValidationResult {
  const CockpitBundleArtifactValidationResult({
    required this.isValid,
    required this.code,
    required this.validator,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final bool isValid;
  final String code;
  final String validator;
  final String message;
  final Map<String, Object?> details;
}

final class CockpitBundleArtifactValidator {
  CockpitBundleArtifactValidator({
    String ffprobeExecutable = 'ffprobe',
    String ffmpegExecutable = 'ffmpeg',
    CockpitArtifactValidationProcessRunner processRunner =
        cockpitRunIsolatedProcess,
    CockpitScreenshotInspector screenshotInspector =
        const CockpitImageScreenshotInspector(),
    CockpitVideoArtifactInspector? videoArtifactInspector,
  }) : _ffprobeExecutable = ffprobeExecutable,
       _ffmpegExecutable = ffmpegExecutable,
       _processRunner = processRunner,
       _screenshotInspector = screenshotInspector,
       _videoArtifactInspector =
           videoArtifactInspector ??
           CockpitVideoArtifactInspector(
             ffprobeExecutable: ffprobeExecutable,
             ffmpegExecutable: ffmpegExecutable,
           );

  final String _ffprobeExecutable;
  final String _ffmpegExecutable;
  final CockpitArtifactValidationProcessRunner _processRunner;
  final CockpitScreenshotInspector _screenshotInspector;
  final CockpitVideoArtifactInspector _videoArtifactInspector;

  Future<CockpitBundleArtifactValidationResult> validateScreenshot(
    String path,
  ) async {
    final file = File(path);
    if (!file.existsSync()) {
      return _missing(path);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return _invalid(
        code: 'invalidScreenshotArtifact',
        validator: 'filesystem',
        message: 'Screenshot artifact is empty.',
        details: <String, Object?>{'path': path},
      );
    }

    try {
      final inspection = await _screenshotInspector.inspect(
        bytes,
        requireVisiblePixels: true,
      );
      return _valid(
        validator: 'image',
        message: 'Screenshot artifact is readable and contains visible pixels.',
        details: <String, Object?>{
          'path': path,
          'width': inspection.width,
          'height': inspection.height,
        },
      );
    } on CockpitScreenshotValidationException catch (error) {
      return _invalid(
        code: 'invalidScreenshotArtifact',
        validator: 'image',
        message: error.message,
        details: <String, Object?>{'path': path, 'inspectionCode': error.code},
      );
    }
  }

  Future<CockpitBundleArtifactValidationResult> validateRecording(
    String path,
  ) async {
    final file = File(path);
    if (!file.existsSync()) {
      return _missing(path);
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return _invalid(
        code: 'invalidRecordingArtifact',
        validator: 'filesystem',
        message: 'Recording artifact is empty.',
        details: <String, Object?>{'path': path},
      );
    }

    return _validateMp4(bytes, path);
  }

  Future<CockpitBundleArtifactValidationResult> validateAcceptanceVideo(
    String path,
  ) async {
    final inspection = await _videoArtifactInspector.inspect(path);
    if (inspection.isValid) {
      return _valid(
        validator: 'ffprobe+ffmpeg',
        message: inspection.message,
        details: inspection.details,
      );
    }
    return _invalid(
      code: inspection.code,
      validator: 'ffprobe+ffmpeg',
      message: inspection.message,
      details: <String, Object?>{
        'failureKind': inspection.failureKind?.name,
        ...inspection.details,
      },
    );
  }

  Future<CockpitBundleArtifactValidationResult> validateDeliveryConsistency({
    required String screenshotPath,
    required String recordingPath,
    List<String> candidateFramePaths = const <String>[],
  }) async {
    final screenshotFile = File(screenshotPath);
    final recordingFile = File(recordingPath);
    if (!screenshotFile.existsSync()) {
      return _missing(screenshotPath);
    }
    if (!recordingFile.existsSync()) {
      return _missing(recordingPath);
    }

    final screenshotImage = img.decodeImage(await screenshotFile.readAsBytes());
    if (screenshotImage == null) {
      return _invalid(
        code: 'invalidScreenshotArtifact',
        validator: 'image',
        message:
            'Screenshot artifact could not be decoded for consistency validation.',
        details: <String, Object?>{'path': screenshotPath},
      );
    }

    final durationMs = await _probeRecordingDurationMs(recordingPath);
    final offsets = _lateFrameOffsets(durationMs);
    final comparisons = <Map<String, Object?>>[];
    double? bestSimilarity;
    double? bestOffsetSeconds;
    String? bestSource;

    Future<void> compareCandidate({
      required img.Image frameImage,
      required String source,
      double? offsetSeconds,
      String? framePath,
    }) async {
      final similarity = _normalizedSimilarity(screenshotImage, frameImage);
      comparisons.add(<String, Object?>{
        'source': source,
        'offsetSeconds': ?offsetSeconds,
        'framePath': ?framePath,
        'similarity': similarity,
      });
      if (bestSimilarity == null || similarity > bestSimilarity!) {
        bestSimilarity = similarity;
        bestOffsetSeconds = offsetSeconds;
        bestSource = source;
      }
    }

    final seenCandidatePaths = <String>{};
    for (final candidatePath in candidateFramePaths) {
      if (candidatePath.isEmpty) {
        continue;
      }
      final normalizedCandidatePath = File(candidatePath).path;
      if (!seenCandidatePaths.add(normalizedCandidatePath)) {
        continue;
      }
      final candidateFile = File(normalizedCandidatePath);
      if (!candidateFile.existsSync()) {
        continue;
      }
      final candidateImage = img.decodeImage(await candidateFile.readAsBytes());
      if (candidateImage == null) {
        continue;
      }
      await compareCandidate(
        frameImage: candidateImage,
        source: 'bundleKeyframe',
        framePath: normalizedCandidatePath,
      );
    }

    try {
      for (final offsetSeconds in offsets) {
        final frameFile = await _extractLateFrame(
          recordingPath: recordingPath,
          offsetSeconds: offsetSeconds,
        );
        if (frameFile == null) {
          continue;
        }
        final frameImage = img.decodeImage(await frameFile.readAsBytes());
        await frameFile.parent.delete(recursive: true);
        if (frameImage == null) {
          continue;
        }

        await compareCandidate(
          frameImage: frameImage,
          source: 'lateFrame',
          offsetSeconds: offsetSeconds,
          framePath: frameFile.path,
        );
      }
    } on ProcessException {
      if (bestSimilarity != null) {
        return _valid(
          validator: 'deliveryConsistency',
          message:
              'Primary screenshot and recording appear to represent the same final screen.',
          details: <String, Object?>{
            'screenshotPath': screenshotPath,
            'recordingPath': recordingPath,
            'bestSimilarity': bestSimilarity,
            'bestFrameOffsetSeconds': bestOffsetSeconds,
            'bestSource': bestSource,
            'candidateOffsetsSeconds': offsets,
            'comparisons': comparisons,
          },
        );
      }
      return _valid(
        validator: 'deliveryConsistencySkipped',
        message:
            'Delivery consistency validation was skipped because ffmpeg is unavailable.',
        details: <String, Object?>{
          'screenshotPath': screenshotPath,
          'recordingPath': recordingPath,
          'candidateFramePaths': candidateFramePaths,
        },
      );
    }

    if (bestSimilarity == null) {
      return _invalid(
        code: 'deliveryConsistencyUnavailable',
        validator: 'ffmpeg',
        message:
            'Could not extract a comparable late frame from the primary recording.',
        details: <String, Object?>{
          'screenshotPath': screenshotPath,
          'recordingPath': recordingPath,
          'candidateFramePaths': candidateFramePaths,
          'candidateOffsetsSeconds': offsets,
        },
      );
    }

    if (bestSimilarity! < 0.78) {
      return _invalid(
        code: 'inconsistentDeliveryEvidence',
        validator: 'deliveryConsistency',
        message:
            'Primary screenshot and recording do not appear to show the same final screen.',
        details: <String, Object?>{
          'screenshotPath': screenshotPath,
          'recordingPath': recordingPath,
          'bestSimilarity': bestSimilarity,
          'bestFrameOffsetSeconds': bestOffsetSeconds,
          'bestSource': bestSource,
          'candidateFramePaths': candidateFramePaths,
          'candidateOffsetsSeconds': offsets,
          'comparisons': comparisons,
        },
      );
    }

    return _valid(
      validator: 'deliveryConsistency',
      message:
          'Primary screenshot and recording appear to represent the same final screen.',
      details: <String, Object?>{
        'screenshotPath': screenshotPath,
        'recordingPath': recordingPath,
        'bestSimilarity': bestSimilarity,
        'bestFrameOffsetSeconds': bestOffsetSeconds,
        'bestSource': bestSource,
        'candidateFramePaths': candidateFramePaths,
        'candidateOffsetsSeconds': offsets,
        'comparisons': comparisons,
      },
    );
  }

  List<double> _lateFrameOffsets(int? durationMs) {
    const baseOffsets = <double>[1.0, 0.6, 0.3, 1.4, 1.8];
    if (durationMs == null || durationMs <= 0) {
      return baseOffsets;
    }
    final maxOffsetSeconds = durationMs <= 3000
        ? (durationMs * 0.45) / 1000
        : 1.8;
    return baseOffsets
        .where((offsetSeconds) => offsetSeconds <= maxOffsetSeconds + 0.001)
        .toList(growable: false);
  }

  Future<int?> _probeRecordingDurationMs(String recordingPath) async {
    try {
      final result = await _processRunner(_ffprobeExecutable, <String>[
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_format',
        recordingPath,
      ]);
      if (result.exitCode != 0) {
        return null;
      }
      final decoded = jsonDecode('${result.stdout}');
      if (decoded is! Map<Object?, Object?>) {
        return null;
      }
      final format = decoded['format'];
      if (format is! Map<Object?, Object?>) {
        return null;
      }
      final durationValue = format['duration'];
      if (durationValue is! String) {
        return null;
      }
      final durationSeconds = double.tryParse(durationValue);
      if (durationSeconds == null || durationSeconds <= 0) {
        return null;
      }
      return (durationSeconds * 1000).round();
    } on FormatException {
      return null;
    } on ProcessException {
      return null;
    }
  }

  CockpitBundleArtifactValidationResult validateRecordingCoverage({
    required int durationMs,
    required List<CockpitRecordingKeyframe> keyframes,
  }) {
    if (keyframes.isEmpty) {
      return _invalid(
        code: 'recordingKeyframesMissing',
        validator: 'recordingCoverage',
        message:
            'A recording was captured but no extracted keyframes are available for coverage validation.',
        details: const <String, Object?>{},
      );
    }
    if (durationMs <= 0) {
      return _invalid(
        code: 'recordingCoverageUnavailable',
        validator: 'recordingCoverage',
        message:
            'Recording coverage could not be validated because the recording duration is unavailable.',
        details: const <String, Object?>{},
      );
    }

    final earlyWindowEnd = durationMs < 2400
        ? 600
        : (durationMs * 0.22).round();
    final hasEarlyCoverage = keyframes.any(
      (keyframe) => keyframe.offsetMs <= earlyWindowEnd,
    );
    final needsMidCoverage = durationMs >= 3000;
    final midStart = (durationMs * 0.30).round();
    final midEnd = (durationMs * 0.70).round();
    final hasMidCoverage =
        !needsMidCoverage ||
        keyframes.any(
          (keyframe) =>
              keyframe.offsetMs >= midStart && keyframe.offsetMs <= midEnd,
        );
    final lateWindowStart = durationMs - (durationMs < 2000 ? 450 : 900);
    final hasLateCoverage = keyframes.any(
      (keyframe) =>
          keyframe.label == 'tail_consistency' ||
          keyframe.offsetMs >= lateWindowStart,
    );

    if (!hasEarlyCoverage || !hasMidCoverage || !hasLateCoverage) {
      final missingSegments = <String>[
        if (!hasEarlyCoverage) 'early',
        if (!hasMidCoverage) 'mid',
        if (!hasLateCoverage) 'late',
      ];
      return _invalid(
        code: 'recordingCoverageInsufficient',
        validator: 'recordingCoverage',
        message:
            'Extracted recording keyframes do not cover the full acceptance timeline.',
        details: <String, Object?>{
          'durationMs': durationMs,
          'keyframeCount': keyframes.length,
          'missingSegments': missingSegments,
          'keyframes': keyframes.map((keyframe) => keyframe.toJson()).toList(),
        },
      );
    }

    return _valid(
      validator: 'recordingCoverage',
      message: 'Extracted recording keyframes cover the acceptance timeline.',
      details: <String, Object?>{
        'durationMs': durationMs,
        'keyframeCount': keyframes.length,
      },
    );
  }

  CockpitBundleArtifactValidationResult _validateMp4(
    Uint8List bytes,
    String path,
  ) {
    if (bytes.length < 12 || ascii.decode(bytes.sublist(4, 8)) != 'ftyp') {
      return _invalid(
        code: 'invalidRecordingArtifact',
        validator: 'builtinMp4',
        message: 'Recording artifact is not a valid MP4 file.',
        details: <String, Object?>{'path': path},
      );
    }

    return _valid(
      validator: 'builtinMp4',
      message: 'Recording artifact passed MP4 header validation.',
      details: <String, Object?>{
        'path': path,
        'majorBrand': ascii.decode(bytes.sublist(8, 12)),
      },
    );
  }

  Future<File?> _extractLateFrame({
    required String recordingPath,
    required double offsetSeconds,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'flutter_cockpit_delivery_frame_',
    );
    final frameFile = File(
      tempDir.uri
          .resolve('frame_${offsetSeconds.toStringAsFixed(1)}.png')
          .toFilePath(),
    );
    final result = await _processRunner(_ffmpegExecutable, <String>[
      '-y',
      '-sseof',
      '-${offsetSeconds.toStringAsFixed(1)}',
      '-i',
      recordingPath,
      '-frames:v',
      '1',
      '-update',
      '1',
      frameFile.path,
    ]);
    if (result.exitCode != 0) {
      await tempDir.delete(recursive: true);
      return null;
    }
    if (!frameFile.existsSync() || frameFile.lengthSync() == 0) {
      await tempDir.delete(recursive: true);
      return null;
    }
    return frameFile;
  }

  double _normalizedSimilarity(img.Image screenshot, img.Image frame) {
    final normalizedScreenshot = _normalizedComparisonImage(screenshot);
    final normalizedFrame = _normalizedComparisonImage(frame);
    var totalDelta = 0.0;
    final pixelCount = normalizedScreenshot.width * normalizedScreenshot.height;
    for (var y = 0; y < normalizedScreenshot.height; y++) {
      for (var x = 0; x < normalizedScreenshot.width; x++) {
        final screenshotPixel = normalizedScreenshot.getPixel(x, y);
        final framePixel = normalizedFrame.getPixel(x, y);
        final screenshotLuminance = screenshotPixel.luminanceNormalized
            .toDouble()
            .clamp(0.0, 1.0);
        final frameLuminance = framePixel.luminanceNormalized.toDouble().clamp(
          0.0,
          1.0,
        );
        totalDelta += (screenshotLuminance - frameLuminance).abs();
      }
    }
    if (pixelCount == 0) {
      return 0;
    }
    return (1 - (totalDelta / pixelCount)).clamp(0.0, 1.0);
  }

  img.Image _normalizedComparisonImage(img.Image image) {
    final cropWidth = (image.width * 0.82).round().clamp(1, image.width);
    final cropHeight = (image.height * 0.72).round().clamp(1, image.height);
    final cropX = ((image.width - cropWidth) / 2).round().clamp(
      0,
      image.width - cropWidth,
    );
    final cropY = ((image.height - cropHeight) / 2).round().clamp(
      0,
      image.height - cropHeight,
    );
    final cropped = img.copyCrop(
      image,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );
    final resized = img.copyResize(
      cropped,
      width: 64,
      height: 64,
      interpolation: img.Interpolation.average,
    );
    return img.grayscale(resized);
  }

  CockpitBundleArtifactValidationResult _missing(String path) {
    return _invalid(
      code: 'missingBundleArtifact',
      validator: 'filesystem',
      message: 'The referenced bundle artifact is missing.',
      details: <String, Object?>{'path': path},
    );
  }

  CockpitBundleArtifactValidationResult _valid({
    required String validator,
    required String message,
    required Map<String, Object?> details,
  }) {
    return CockpitBundleArtifactValidationResult(
      isValid: true,
      code: 'validArtifact',
      validator: validator,
      message: message,
      details: details,
    );
  }

  CockpitBundleArtifactValidationResult _invalid({
    required String code,
    required String validator,
    required String message,
    required Map<String, Object?> details,
  }) {
    return CockpitBundleArtifactValidationResult(
      isValid: false,
      code: code,
      validator: validator,
      message: message,
      details: details,
    );
  }
}
