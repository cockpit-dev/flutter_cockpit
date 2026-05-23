import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

typedef CockpitRecordingKeyframeProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

enum CockpitRecordingKeyframeSource {
  stepCapture,
  syntheticCoverage,
  tailConsistency;

  static CockpitRecordingKeyframeSource fromJson(Object? json) {
    return values.byName(json! as String);
  }
}

final class CockpitRecordingKeyframe {
  const CockpitRecordingKeyframe({
    required this.relativePath,
    required this.label,
    required this.offsetMs,
    required this.source,
    this.linkedScreenshotRef,
  });

  final String relativePath;
  final String label;
  final int offsetMs;
  final CockpitRecordingKeyframeSource source;
  final String? linkedScreenshotRef;

  Map<String, Object?> toJson() => <String, Object?>{
    'ref': relativePath,
    'label': label,
    'offsetMs': offsetMs,
    'source': source.name,
    'linkedScreenshotRef': linkedScreenshotRef,
  };

  factory CockpitRecordingKeyframe.fromJson(Map<String, Object?> json) {
    return CockpitRecordingKeyframe(
      relativePath: json['ref']! as String,
      label: json['label']! as String,
      offsetMs: json['offsetMs']! as int,
      source: CockpitRecordingKeyframeSource.fromJson(json['source']),
      linkedScreenshotRef: json['linkedScreenshotRef'] as String?,
    );
  }
}

final class CockpitRecordingCoverage {
  const CockpitRecordingCoverage({
    required this.durationMs,
    required this.hasEarlyCoverage,
    required this.hasMidCoverage,
    required this.hasLateCoverage,
  });

  final int durationMs;
  final bool hasEarlyCoverage;
  final bool hasMidCoverage;
  final bool hasLateCoverage;

  bool get isReady =>
      durationMs > 0 && hasEarlyCoverage && hasMidCoverage && hasLateCoverage;

  Map<String, Object?> toJson() => <String, Object?>{
    'durationMs': durationMs,
    'hasEarlyCoverage': hasEarlyCoverage,
    'hasMidCoverage': hasMidCoverage,
    'hasLateCoverage': hasLateCoverage,
    'isReady': isReady,
  };

  factory CockpitRecordingCoverage.fromJson(Map<String, Object?> json) {
    return CockpitRecordingCoverage(
      durationMs: json['durationMs']! as int,
      hasEarlyCoverage: json['hasEarlyCoverage']! as bool,
      hasMidCoverage: json['hasMidCoverage']! as bool,
      hasLateCoverage: json['hasLateCoverage']! as bool,
    );
  }
}

final class CockpitRecordingKeyframeExtractionResult {
  const CockpitRecordingKeyframeExtractionResult({
    required this.keyframes,
    required this.artifactPayloads,
    required this.coverage,
    this.failureReason,
  });

  final List<CockpitRecordingKeyframe> keyframes;
  final Map<String, List<int>> artifactPayloads;
  final CockpitRecordingCoverage coverage;
  final String? failureReason;
}

abstract interface class CockpitRecordingKeyframeExtractor {
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  });
}

final class DefaultCockpitRecordingKeyframeExtractor
    implements CockpitRecordingKeyframeExtractor {
  const DefaultCockpitRecordingKeyframeExtractor({
    String ffprobeExecutable = 'ffprobe',
    String ffmpegExecutable = 'ffmpeg',
    CockpitRecordingKeyframeProcessRunner processRunner = Process.run,
  }) : _ffprobeExecutable = ffprobeExecutable,
       _ffmpegExecutable = ffmpegExecutable,
       _processRunner = processRunner;

  final String _ffprobeExecutable;
  final String _ffmpegExecutable;
  final CockpitRecordingKeyframeProcessRunner _processRunner;

  @override
  Future<CockpitRecordingKeyframeExtractionResult> extract({
    required String recordingPath,
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    String? bundleDirectoryPath,
  }) async {
    final durationMs = await _recordingDurationMs(recordingPath, steps);
    if (durationMs <= 0) {
      return CockpitRecordingKeyframeExtractionResult(
        keyframes: const <CockpitRecordingKeyframe>[],
        artifactPayloads: const <String, List<int>>{},
        coverage: const CockpitRecordingCoverage(
          durationMs: 0,
          hasEarlyCoverage: false,
          hasMidCoverage: false,
          hasLateCoverage: false,
        ),
        failureReason: 'recordingDurationUnavailable',
      );
    }

    final plan = _buildPlan(
      recordingRelativePath: recordingRelativePath,
      steps: steps,
      durationMs: durationMs,
    );
    if (plan.isEmpty) {
      return CockpitRecordingKeyframeExtractionResult(
        keyframes: const <CockpitRecordingKeyframe>[],
        artifactPayloads: const <String, List<int>>{},
        coverage: const CockpitRecordingCoverage(
          durationMs: 0,
          hasEarlyCoverage: false,
          hasMidCoverage: false,
          hasLateCoverage: false,
        ),
        failureReason: 'recordingKeyframePlanEmpty',
      );
    }

    final extractedKeyframes = <CockpitRecordingKeyframe>[];
    final artifactPayloads = <String, List<int>>{};
    final tempDir = await Directory.systemTemp.createTemp(
      'flutter_cockpit_keyframes_',
    );
    final acceptanceImage = _readAcceptanceScreenshotImage(
      bundleDirectoryPath: bundleDirectoryPath,
      acceptanceScreenshotRef: _acceptanceScreenshotRef(plan),
    );
    try {
      for (final planned in plan) {
        final shouldMatchAcceptanceImage =
            acceptanceImage != null &&
            (planned.label == 'acceptance' ||
                planned.source ==
                    CockpitRecordingKeyframeSource.tailConsistency);
        if (shouldMatchAcceptanceImage) {
          final selected = await _extractBestMatchingTailKeyframe(
            planned: planned,
            durationMs: durationMs,
            recordingPath: recordingPath,
            tempDir: tempDir,
            acceptanceImage: acceptanceImage,
          );
          if (selected != null) {
            artifactPayloads[planned.path] = selected.bytes;
            extractedKeyframes.add(
              CockpitRecordingKeyframe(
                relativePath: planned.path,
                label: planned.label,
                offsetMs: selected.offsetMs,
                source: planned.source,
                linkedScreenshotRef: planned.linkedScreenshotRef,
              ),
            );
            continue;
          }
        }
        final outputFile = File(p.join(tempDir.path, p.basename(planned.path)));
        for (final attempt in _attemptsForPlannedKeyframe(
          planned: planned,
          durationMs: durationMs,
        )) {
          if (outputFile.existsSync()) {
            outputFile.deleteSync();
          }
          final result = await _processRunner(
            _ffmpegExecutable,
            _ffmpegArgumentsForPlannedKeyframe(
              planned: attempt,
              durationMs: durationMs,
              recordingPath: recordingPath,
              outputPath: outputFile.path,
            ),
          );
          if (result.exitCode != 0 ||
              !outputFile.existsSync() ||
              outputFile.lengthSync() == 0) {
            continue;
          }

          artifactPayloads[planned.path] = await outputFile.readAsBytes();
          extractedKeyframes.add(
            CockpitRecordingKeyframe(
              relativePath: planned.path,
              label: planned.label,
              offsetMs: attempt.offsetMs,
              source: planned.source,
              linkedScreenshotRef: planned.linkedScreenshotRef,
            ),
          );
          break;
        }
      }
    } on ProcessException {
      return CockpitRecordingKeyframeExtractionResult(
        keyframes: const <CockpitRecordingKeyframe>[],
        artifactPayloads: const <String, List<int>>{},
        coverage: CockpitRecordingCoverage(
          durationMs: durationMs,
          hasEarlyCoverage: false,
          hasMidCoverage: false,
          hasLateCoverage: false,
        ),
        failureReason: 'keyframeExtractorUnavailable',
      );
    } finally {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    }

    final coverage = _coverageFor(
      durationMs: durationMs,
      keyframes: extractedKeyframes,
    );
    return CockpitRecordingKeyframeExtractionResult(
      keyframes: List<CockpitRecordingKeyframe>.unmodifiable(
        extractedKeyframes,
      ),
      artifactPayloads: Map<String, List<int>>.unmodifiable(artifactPayloads),
      coverage: coverage,
      failureReason: extractedKeyframes.isEmpty
          ? 'recordingKeyframeExtractionFailed'
          : null,
    );
  }

  Future<_ExtractedKeyframeCandidate?> _extractBestMatchingTailKeyframe({
    required _PlannedKeyframe planned,
    required int durationMs,
    required String recordingPath,
    required Directory tempDir,
    required img.Image acceptanceImage,
  }) async {
    _ExtractedKeyframeCandidate? bestCandidate;
    for (final attempt in _attemptsForPlannedKeyframe(
      planned: planned,
      durationMs: durationMs,
    )) {
      final outputFile = File(p.join(tempDir.path, p.basename(planned.path)));
      if (outputFile.existsSync()) {
        outputFile.deleteSync();
      }
      final result = await _processRunner(
        _ffmpegExecutable,
        _ffmpegArgumentsForPlannedKeyframe(
          planned: attempt,
          durationMs: durationMs,
          recordingPath: recordingPath,
          outputPath: outputFile.path,
        ),
      );
      if (result.exitCode != 0 ||
          !outputFile.existsSync() ||
          outputFile.lengthSync() == 0) {
        continue;
      }

      final bytes = await outputFile.readAsBytes();
      final candidateImage = img.decodeImage(bytes);
      if (candidateImage == null) {
        continue;
      }
      final similarity = _normalizedSimilarity(acceptanceImage, candidateImage);
      if (bestCandidate == null || similarity > bestCandidate.similarity) {
        bestCandidate = _ExtractedKeyframeCandidate(
          bytes: bytes,
          offsetMs: attempt.offsetMs,
          similarity: similarity,
        );
      }
    }
    return bestCandidate;
  }

  List<String> _ffmpegArgumentsForPlannedKeyframe({
    required _PlannedKeyframe planned,
    required int durationMs,
    required String recordingPath,
    required String outputPath,
  }) {
    final baseArguments = <String>[
      '-y',
      ...switch (planned.source) {
        CockpitRecordingKeyframeSource.tailConsistency => <String>[
          '-sseof',
          '-${_tailSeekSeconds(durationMs, planned.offsetMs)}',
          '-i',
          recordingPath,
        ],
        _ => <String>[
          '-ss',
          (planned.offsetMs / 1000).toStringAsFixed(3),
          '-i',
          recordingPath,
        ],
      },
      '-frames:v',
      '1',
      '-update',
      '1',
      outputPath,
    ];
    return baseArguments;
  }

  List<_PlannedKeyframe> _attemptsForPlannedKeyframe({
    required _PlannedKeyframe planned,
    required int durationMs,
  }) {
    final attempts = <_PlannedKeyframe>[];
    final seenOffsets = <int>{};
    final isSyntheticCoverage =
        planned.source == CockpitRecordingKeyframeSource.syntheticCoverage;
    final isLateSensitive =
        planned.label == 'acceptance' ||
        planned.label == 'tail_consistency' ||
        planned.offsetMs >= durationMs - 650;

    void addAttempt(int offsetMs) {
      final clampedOffset = offsetMs.clamp(0, durationMs <= 0 ? 0 : durationMs);
      if (isLateSensitive &&
          !_isAllowedLateProbeOffset(durationMs, clampedOffset)) {
        return;
      }
      if (!seenOffsets.add(clampedOffset)) {
        return;
      }
      attempts.add(planned.copyWith(offsetMs: clampedOffset));
    }

    addAttempt(planned.offsetMs);
    if (isSyntheticCoverage) {
      addAttempt(planned.offsetMs - 150);
      addAttempt(planned.offsetMs - 300);
      addAttempt(planned.offsetMs - 600);
    }

    if (!isLateSensitive) {
      return attempts;
    }

    addAttempt(durationMs - 600);
    addAttempt(durationMs - 900);
    addAttempt(durationMs - 1200);
    addAttempt(durationMs - 1500);
    addAttempt(durationMs - 1800);
    return attempts;
  }

  bool _isAllowedLateProbeOffset(int durationMs, int offsetMs) {
    if (durationMs <= 0) {
      return true;
    }
    if (durationMs > 3000) {
      return durationMs - offsetMs <= 1800;
    }
    final maxDistanceFromEndMs = (durationMs * 0.45).round();
    return durationMs - offsetMs <= maxDistanceFromEndMs;
  }

  String _tailSeekSeconds(int durationMs, int offsetMs) {
    final distanceFromEndMs = durationMs - offsetMs;
    final clampedMs = distanceFromEndMs <= 0 ? 50 : distanceFromEndMs;
    return (clampedMs / 1000).toStringAsFixed(3);
  }

  Future<int> _recordingDurationMs(
    String recordingPath,
    List<CockpitStepRecord> steps,
  ) async {
    try {
      final result = await _processRunner(_ffprobeExecutable, <String>[
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_format',
        '-show_streams',
        recordingPath,
      ]);
      if (result.exitCode == 0) {
        final decoded = jsonDecode('${result.stdout}');
        if (decoded is Map<Object?, Object?>) {
          final format = decoded['format'];
          if (format is Map<Object?, Object?>) {
            final durationValue = format['duration'];
            if (durationValue is String) {
              final durationSeconds = double.tryParse(durationValue);
              if (durationSeconds != null && durationSeconds > 0) {
                return (durationSeconds * 1000).round();
              }
            }
          }
        }
      }
    } on ProcessException {
      // fall through
    } on FormatException {
      // fall through
    }

    final recordingStopped = steps.lastWhere(
      (step) => step.actionType == 'recording_stopped',
      orElse: () => CockpitStepRecord(
        index: -1,
        actionType: 'missing',
        actionArgs: const <String, Object?>{},
        observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
    final durationArg = recordingStopped.actionArgs['recordingDurationMs'];
    if (durationArg is int && durationArg > 0) {
      return durationArg;
    }

    final recordingStarted = steps.firstWhere(
      (step) => step.actionType == 'recording_started',
      orElse: () => CockpitStepRecord(
        index: -1,
        actionType: 'missing',
        actionArgs: const <String, Object?>{},
        observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
    if (recordingStarted.index >= 0 && recordingStopped.index >= 0) {
      return recordingStopped.observedAt
          .difference(recordingStarted.observedAt)
          .inMilliseconds;
    }
    return 0;
  }

  List<_PlannedKeyframe> _buildPlan({
    required String recordingRelativePath,
    required List<CockpitStepRecord> steps,
    required int durationMs,
  }) {
    final candidates = <_PlannedKeyframe>[];
    final recordingBaseName = p.basenameWithoutExtension(recordingRelativePath);
    final recordingStarted = steps.firstWhere(
      (step) => step.actionType == 'recording_started',
      orElse: () => steps.firstWhere(
        (step) => step.actionType == 'recording_start_requested',
        orElse: () => CockpitStepRecord(
          index: -1,
          actionType: 'missing',
          actionArgs: const <String, Object?>{},
          observedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      ),
    );
    final recordingStartTime = recordingStarted.index >= 0
        ? recordingStarted.observedAt
        : steps.firstOrNull?.observedAt;
    final earlyWindowEnd = _earlyCoverageWindowMs(durationMs);

    if (recordingStartTime != null) {
      final screenshotSteps =
          steps
              .where((step) {
                return step.captureRefs.any(
                  (artifact) => artifact.role == 'screenshot',
                );
              })
              .toList(growable: false)
            ..sort(
              (left, right) => left.observedAt.compareTo(right.observedAt),
            );

      for (var index = 0; index < screenshotSteps.length; index++) {
        final step = screenshotSteps[index];
        final offsetMs = step.observedAt
            .difference(recordingStartTime)
            .inMilliseconds
            .clamp(0, durationMs);
        final screenshotRef = step.captureRefs
            .where((artifact) => artifact.role == 'screenshot')
            .map((artifact) => artifact.relativePath)
            .lastOrNull;
        final label = switch (step.requestedCaptureProfile) {
          CockpitCaptureProfile.acceptance ||
          CockpitCaptureProfile.nativePreferred => 'acceptance',
          _ when index == 0 && offsetMs <= earlyWindowEnd => 'baseline',
          _ => 'step_capture_${step.index.toString().padLeft(3, '0')}',
        };
        candidates.add(
          _PlannedKeyframe(
            path:
                'keyframes/${recordingBaseName}_${label}_${offsetMs.toString().padLeft(5, '0')}.png',
            label: label,
            offsetMs: offsetMs,
            source: CockpitRecordingKeyframeSource.stepCapture,
            linkedScreenshotRef: screenshotRef,
          ),
        );
      }
    }

    if (!candidates.any((candidate) => candidate.label == 'baseline')) {
      final baselineOffset = (durationMs * 0.12).round().clamp(0, durationMs);
      candidates.add(
        _PlannedKeyframe(
          path:
              'keyframes/${recordingBaseName}_baseline_${baselineOffset.toString().padLeft(5, '0')}.png',
          label: 'baseline',
          offsetMs: baselineOffset,
          source: CockpitRecordingKeyframeSource.syntheticCoverage,
        ),
      );
    }

    if (!candidates.any((candidate) => candidate.label == 'midpoint')) {
      final midpointOffset = (durationMs * 0.5).round();
      candidates.add(
        _PlannedKeyframe(
          path:
              'keyframes/${recordingBaseName}_midpoint_${midpointOffset.toString().padLeft(5, '0')}.png',
          label: 'midpoint',
          offsetMs: midpointOffset,
          source: CockpitRecordingKeyframeSource.syntheticCoverage,
        ),
      );
    }

    if (!candidates.any((candidate) => candidate.label == 'acceptance')) {
      final acceptanceOffset = (durationMs * 0.82).round().clamp(0, durationMs);
      candidates.add(
        _PlannedKeyframe(
          path:
              'keyframes/${recordingBaseName}_acceptance_${acceptanceOffset.toString().padLeft(5, '0')}.png',
          label: 'acceptance',
          offsetMs: acceptanceOffset,
          source: CockpitRecordingKeyframeSource.syntheticCoverage,
        ),
      );
    }

    final tailOffset = durationMs < 800
        ? (durationMs * 0.82).round().clamp(0, durationMs)
        : durationMs - 600;
    candidates.add(
      _PlannedKeyframe(
        path:
            'keyframes/${recordingBaseName}_tail_consistency_${tailOffset.toString().padLeft(5, '0')}.png',
        label: 'tail_consistency',
        offsetMs: tailOffset,
        source: CockpitRecordingKeyframeSource.tailConsistency,
      ),
    );

    candidates.sort((left, right) => left.offsetMs.compareTo(right.offsetMs));
    final deduped = <_PlannedKeyframe>[];
    for (final candidate in candidates) {
      final existingIndex = deduped.indexWhere(
        (existing) =>
            existing.label == candidate.label ||
            _shouldDedupByOffset(existing, candidate),
      );
      if (existingIndex == -1) {
        deduped.add(candidate);
        continue;
      }
      final existing = deduped[existingIndex];
      final shouldReplace =
          existing.source != CockpitRecordingKeyframeSource.stepCapture &&
          candidate.source == CockpitRecordingKeyframeSource.stepCapture;
      if (shouldReplace) {
        deduped[existingIndex] = candidate;
      }
    }
    return deduped;
  }

  bool _shouldDedupByOffset(_PlannedKeyframe left, _PlannedKeyframe right) {
    final preservesLateCoverage =
        left.label == 'tail_consistency' || right.label == 'tail_consistency';
    if (preservesLateCoverage) {
      return false;
    }
    return (left.offsetMs - right.offsetMs).abs() <= 250;
  }

  CockpitRecordingCoverage _coverageFor({
    required int durationMs,
    required List<CockpitRecordingKeyframe> keyframes,
  }) {
    if (durationMs <= 0 || keyframes.isEmpty) {
      return const CockpitRecordingCoverage(
        durationMs: 0,
        hasEarlyCoverage: false,
        hasMidCoverage: false,
        hasLateCoverage: false,
      );
    }

    final earlyCoverage = keyframes.any(
      (keyframe) => keyframe.offsetMs <= _earlyCoverageWindowMs(durationMs),
    );
    final needsMidCoverage = durationMs >= 3000;
    final midStart = (durationMs * 0.30).round();
    final midEnd = (durationMs * 0.70).round();
    final midCoverage =
        !needsMidCoverage ||
        keyframes.any(
          (keyframe) =>
              keyframe.offsetMs >= midStart && keyframe.offsetMs <= midEnd,
        );
    final lateCoverageWindowStart =
        durationMs - (durationMs < 2000 ? 450 : 900);
    final lateCoverage = keyframes.any(
      (keyframe) =>
          keyframe.label == 'tail_consistency' ||
          keyframe.offsetMs >= lateCoverageWindowStart,
    );
    return CockpitRecordingCoverage(
      durationMs: durationMs,
      hasEarlyCoverage: earlyCoverage,
      hasMidCoverage: midCoverage,
      hasLateCoverage: lateCoverage,
    );
  }

  int _earlyCoverageWindowMs(int durationMs) {
    return (durationMs < 2400 ? 600 : durationMs * 0.22).round();
  }

  String? _acceptanceScreenshotRef(List<_PlannedKeyframe> plan) {
    return plan
        .where(
          (candidate) =>
              candidate.label == 'acceptance' &&
              candidate.linkedScreenshotRef != null,
        )
        .map((candidate) => candidate.linkedScreenshotRef)
        .whereType<String>()
        .lastOrNull;
  }

  img.Image? _readAcceptanceScreenshotImage({
    required String? bundleDirectoryPath,
    required String? acceptanceScreenshotRef,
  }) {
    if (bundleDirectoryPath == null || acceptanceScreenshotRef == null) {
      return null;
    }
    final acceptanceFile = File(
      p.join(bundleDirectoryPath, acceptanceScreenshotRef),
    );
    if (!acceptanceFile.existsSync()) {
      return null;
    }
    return img.decodeImage(acceptanceFile.readAsBytesSync());
  }

  double _normalizedSimilarity(img.Image screenshot, img.Image frame) {
    final normalizedScreenshot = _normalizedComparisonImage(screenshot);
    final normalizedFrame = _normalizedComparisonImage(frame);
    var totalDelta = 0;
    final pixelCount = normalizedScreenshot.width * normalizedScreenshot.height;
    for (var y = 0; y < normalizedScreenshot.height; y++) {
      for (var x = 0; x < normalizedScreenshot.width; x++) {
        final screenshotPixel = normalizedScreenshot.getPixel(x, y);
        final framePixel = normalizedFrame.getPixel(x, y);
        totalDelta +=
            (img.getLuminance(screenshotPixel) - img.getLuminance(framePixel))
                .abs()
                .round();
      }
    }
    final maxDelta = pixelCount * 255;
    return 1 - (totalDelta / maxDelta);
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
}

final class _PlannedKeyframe {
  const _PlannedKeyframe({
    required this.path,
    required this.label,
    required this.offsetMs,
    required this.source,
    this.linkedScreenshotRef,
  });

  final String path;
  final String label;
  final int offsetMs;
  final CockpitRecordingKeyframeSource source;
  final String? linkedScreenshotRef;

  _PlannedKeyframe copyWith({int? offsetMs}) {
    return _PlannedKeyframe(
      path: path,
      label: label,
      offsetMs: offsetMs ?? this.offsetMs,
      source: source,
      linkedScreenshotRef: linkedScreenshotRef,
    );
  }
}

final class _ExtractedKeyframeCandidate {
  const _ExtractedKeyframeCandidate({
    required this.bytes,
    required this.offsetMs,
    required this.similarity,
  });

  final List<int> bytes;
  final int offsetMs;
  final double similarity;
}

extension on Iterable<CockpitStepRecord> {
  CockpitStepRecord? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}

extension on Iterable<String> {
  String? get lastOrNull {
    final iterator = this.iterator;
    String? current;
    while (iterator.moveNext()) {
      current = iterator.current;
    }
    return current;
  }
}
