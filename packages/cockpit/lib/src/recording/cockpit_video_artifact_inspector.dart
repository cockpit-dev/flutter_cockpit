import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../infrastructure/cockpit_process_manager.dart';

typedef CockpitVideoArtifactProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      required Duration timeout,
    });

enum CockpitVideoArtifactFailureKind { invalidMedia, validatorUnavailable }

final class CockpitVideoArtifactInspectionResult {
  const CockpitVideoArtifactInspectionResult({
    required this.isValid,
    required this.code,
    required this.message,
    required this.details,
    this.failureKind,
  });

  final bool isValid;
  final String code;
  final CockpitVideoArtifactFailureKind? failureKind;
  final String message;
  final Map<String, Object?> details;
}

final class CockpitVideoArtifactInspector {
  CockpitVideoArtifactInspector({
    String ffprobeExecutable = 'ffprobe',
    String ffmpegExecutable = 'ffmpeg',
    Duration probeTimeout = const Duration(seconds: 10),
    Duration decodeTimeout = const Duration(seconds: 10),
    CockpitVideoArtifactProcessRunner processRunner = _runProcess,
  }) : _ffprobeExecutable = ffprobeExecutable,
       _ffmpegExecutable = ffmpegExecutable,
       _probeTimeout = probeTimeout,
       _decodeTimeout = decodeTimeout,
       _processRunner = processRunner;

  final String _ffprobeExecutable;
  final String _ffmpegExecutable;
  final Duration _probeTimeout;
  final Duration _decodeTimeout;
  final CockpitVideoArtifactProcessRunner _processRunner;

  Future<CockpitVideoArtifactInspectionResult> inspect(String path) async {
    final file = File(path);
    try {
      if (!file.existsSync()) {
        return _invalid(
          code: 'videoArtifactMissing',
          message: 'The video artifact is missing.',
          details: <String, Object?>{'path': path},
        );
      }
      if (file.lengthSync() <= 0) {
        return _invalid(
          code: 'videoArtifactEmpty',
          message: 'The video artifact is empty.',
          details: <String, Object?>{'path': path},
        );
      }
    } on FileSystemException catch (error) {
      return _invalid(
        code: 'videoArtifactUnreadable',
        message: 'The video artifact could not be read.',
        details: <String, Object?>{'path': path, 'error': '$error'},
      );
    }

    final ProcessResult probeResult;
    try {
      probeResult = await _processRunner(_ffprobeExecutable, <String>[
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_entries',
        'stream=codec_name,codec_type,width,height:format=duration',
        path,
      ], timeout: _probeTimeout);
    } on ProcessException catch (error) {
      return _unavailable(
        executable: _ffprobeExecutable,
        path: path,
        error: error,
      );
    } on TimeoutException catch (error) {
      return _timedOut(
        executable: _ffprobeExecutable,
        path: path,
        timeout: _probeTimeout,
        error: error,
      );
    }

    if (probeResult.exitCode != 0) {
      return _invalid(
        code: 'videoProbeFailed',
        message: 'ffprobe could not inspect the video artifact.',
        details: <String, Object?>{
          'path': path,
          'exitCode': probeResult.exitCode,
          'stderr': _boundedOutput(probeResult.stderr),
        },
      );
    }

    final Map<String, Object?> payload;
    try {
      final decoded = jsonDecode('${probeResult.stdout}');
      if (decoded is! Map<Object?, Object?>) {
        return _malformedProbe(path);
      }
      payload = Map<String, Object?>.from(decoded);
    } on FormatException {
      return _malformedProbe(path);
    }

    final streamsValue = payload['streams'];
    final formatValue = payload['format'];
    if (streamsValue is! List<Object?> ||
        formatValue is! Map<Object?, Object?>) {
      return _malformedProbe(path);
    }
    final streams = streamsValue
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, Object?>.from)
        .toList(growable: false);
    final videoStreams = streams
        .where((stream) => stream['codec_type'] == 'video')
        .toList(growable: false);
    if (videoStreams.isEmpty) {
      return _invalid(
        code: 'videoStreamMissing',
        message: 'The artifact does not contain a video stream.',
        details: <String, Object?>{'path': path},
      );
    }

    Map<String, Object?>? usableStream;
    for (final stream in videoStreams) {
      final codecName = stream['codec_name'];
      final width = stream['width'];
      final height = stream['height'];
      if (codecName is String &&
          codecName.trim().isNotEmpty &&
          width is int &&
          width > 0 &&
          height is int &&
          height > 0) {
        usableStream = stream;
        break;
      }
    }
    if (usableStream == null) {
      final dimensionStream = videoStreams.firstWhere(
        (stream) => stream['width'] is int && stream['height'] is int,
        orElse: () => const <String, Object?>{},
      );
      if (dimensionStream.isNotEmpty) {
        return _invalid(
          code: 'videoInvalidDimensions',
          message: 'Video dimensions must be positive.',
          details: <String, Object?>{
            'path': path,
            'width': dimensionStream['width'],
            'height': dimensionStream['height'],
          },
        );
      }
      return _invalid(
        code: 'videoStreamInvalid',
        message: 'The artifact does not contain a usable video stream.',
        details: <String, Object?>{'path': path},
      );
    }

    final format = Map<String, Object?>.from(formatValue);
    final durationSeconds = _positiveDuration(format['duration']);
    if (durationSeconds == null) {
      return _invalid(
        code: 'videoInvalidDuration',
        message: 'Video duration must be positive.',
        details: <String, Object?>{
          'path': path,
          'duration': format['duration'],
        },
      );
    }

    final ProcessResult decodeResult;
    try {
      decodeResult = await _processRunner(_ffmpegExecutable, <String>[
        '-v',
        'error',
        '-i',
        path,
        '-frames:v',
        '1',
        '-f',
        'null',
        '-',
      ], timeout: _decodeTimeout);
    } on ProcessException catch (error) {
      return _unavailable(
        executable: _ffmpegExecutable,
        path: path,
        error: error,
      );
    } on TimeoutException catch (error) {
      return _timedOut(
        executable: _ffmpegExecutable,
        path: path,
        timeout: _decodeTimeout,
        error: error,
      );
    }

    if (decodeResult.exitCode != 0) {
      return _invalid(
        code: 'videoDecodeFailed',
        message: 'ffmpeg could not decode a video frame.',
        details: <String, Object?>{
          'path': path,
          'exitCode': decodeResult.exitCode,
          'stderr': _boundedOutput(decodeResult.stderr),
        },
      );
    }

    return CockpitVideoArtifactInspectionResult(
      isValid: true,
      code: 'validVideoArtifact',
      message: 'Video metadata is usable and one frame decoded successfully.',
      details: <String, Object?>{
        'path': path,
        'codecName': usableStream['codec_name'],
        'width': usableStream['width'],
        'height': usableStream['height'],
        'durationSeconds': durationSeconds,
      },
    );
  }

  double? _positiveDuration(Object? value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text),
      _ => null,
    };
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
  }

  CockpitVideoArtifactInspectionResult _malformedProbe(String path) {
    return _invalid(
      code: 'videoProbeMalformed',
      message: 'ffprobe returned malformed video metadata.',
      details: <String, Object?>{'path': path},
    );
  }

  CockpitVideoArtifactInspectionResult _unavailable({
    required String executable,
    required String path,
    required ProcessException error,
  }) {
    return CockpitVideoArtifactInspectionResult(
      isValid: false,
      code: 'videoValidatorUnavailable',
      failureKind: CockpitVideoArtifactFailureKind.validatorUnavailable,
      message: 'Required video validation tool is unavailable.',
      details: <String, Object?>{
        'path': path,
        'executable': executable,
        'error': '$error',
      },
    );
  }

  CockpitVideoArtifactInspectionResult _timedOut({
    required String executable,
    required String path,
    required Duration timeout,
    required TimeoutException error,
  }) {
    return CockpitVideoArtifactInspectionResult(
      isValid: false,
      code: 'videoValidationTimedOut',
      failureKind: CockpitVideoArtifactFailureKind.validatorUnavailable,
      message: 'Video validation exceeded its time limit.',
      details: <String, Object?>{
        'path': path,
        'executable': executable,
        'timeoutMs': timeout.inMilliseconds,
        'error': '$error',
      },
    );
  }

  CockpitVideoArtifactInspectionResult _invalid({
    required String code,
    required String message,
    required Map<String, Object?> details,
  }) {
    return CockpitVideoArtifactInspectionResult(
      isValid: false,
      code: code,
      failureKind: CockpitVideoArtifactFailureKind.invalidMedia,
      message: message,
      details: details,
    );
  }

  String _boundedOutput(Object? value) {
    const maxLength = 2048;
    final output = '$value'.trim();
    return output.length <= maxLength
        ? output
        : '${output.substring(0, maxLength)}...';
  }
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments, {
  required Duration timeout,
}) async {
  final process = await cockpitStartIsolatedProcess(executable, arguments);
  final stdoutFuture = process.stdout.transform(utf8.decoder).join();
  final stderrFuture = process.stderr.transform(utf8.decoder).join();
  try {
    final exitCode = await process.exitCode.timeout(timeout);
    final output = await Future.wait(<Future<String>>[
      stdoutFuture,
      stderrFuture,
    ]);
    return ProcessResult(process.pid, exitCode, output[0], output[1]);
  } on TimeoutException {
    process.kill();
    await _settleAfterKill(process.exitCode);
    await _settleAfterKill(stdoutFuture);
    await _settleAfterKill(stderrFuture);
    throw TimeoutException(
      '$executable exceeded ${timeout.inMilliseconds}ms.',
      timeout,
    );
  }
}

Future<void> _settleAfterKill(Future<Object?> future) async {
  try {
    await future.timeout(const Duration(seconds: 1));
  } on Object {
    // Process termination and pipe closure are best-effort after a timeout.
  }
}
