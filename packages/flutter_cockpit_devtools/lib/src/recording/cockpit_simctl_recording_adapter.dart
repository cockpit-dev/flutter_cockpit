import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_host_recording_adapter.dart';

final class CockpitSimctlRecordingAdapter
    implements CockpitHostRecordingAdapter {
  CockpitSimctlRecordingAdapter({
    required String deviceId,
    String executable = 'xcrun',
    CockpitRecordingProcessStarter processStarter = Process.start,
    CockpitRecordingProcessRunner processRunner = Process.run,
    CockpitRecordingTempFileFactory tempFileFactory =
        cockpitCreateRecordingTempFile,
    String ffprobeExecutable = 'ffprobe',
    Duration startupTimeout = const Duration(seconds: 5),
    Duration stopTimeout = const Duration(seconds: 10),
    Duration finalizationPollInterval = const Duration(milliseconds: 100),
  })  : _deviceId = deviceId,
        _executable = executable,
        _processStarter = processStarter,
        _processRunner = processRunner,
        _tempFileFactory = tempFileFactory,
        _ffprobeExecutable = ffprobeExecutable,
        _startupTimeout = startupTimeout,
        _stopTimeout = stopTimeout,
        _finalizationPollInterval = finalizationPollInterval;

  final String _deviceId;
  final String _executable;
  final CockpitRecordingProcessStarter _processStarter;
  final CockpitRecordingProcessRunner _processRunner;
  final CockpitRecordingTempFileFactory _tempFileFactory;
  final String _ffprobeExecutable;
  final Duration _startupTimeout;
  final Duration _stopTimeout;
  final Duration _finalizationPollInterval;

  Process? _process;
  CockpitRecordingRequest? _request;
  File? _outputFile;
  StreamSubscription<String>? _stderrSubscription;
  Stopwatch? _stopwatch;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    if (_process != null) {
      throw StateError('A simctl recording is already active.');
    }

    final outputFile = await _tempFileFactory(
      cockpitRecordingFileName(request.name),
    );
    outputFile.parent.createSync(recursive: true);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    final process = await _processStarter(_executable, <String>[
      'simctl',
      'io',
      _deviceId,
      'recordVideo',
      '--force',
      outputFile.path,
    ]);

    unawaited(process.stdout.drain<void>());

    final startupCompleter = Completer<void>();
    final stderrBuffer = StringBuffer();
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stderrBuffer.writeln(line);
      if (!startupCompleter.isCompleted && line.contains('Recording started')) {
        startupCompleter.complete();
      }
    });

    try {
      await Future.any<void>(<Future<void>>[
        startupCompleter.future,
        process.exitCode.then((exitCode) {
          throw StateError(
            'simctl recordVideo exited before startup (exitCode=$exitCode): ${stderrBuffer.toString().trim()}',
          );
        }),
      ]).timeout(_startupTimeout);
    } on Object {
      await stderrSubscription.cancel();
      process.kill(ProcessSignal.sigkill);
      rethrow;
    }

    _process = process;
    _request = request;
    _outputFile = outputFile;
    _stderrSubscription = stderrSubscription;
    _stopwatch = Stopwatch()..start();

    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    final process = _process;
    final request = _request;
    final outputFile = _outputFile;
    final stopwatch = _stopwatch;
    if (process == null || request == null || outputFile == null) {
      throw StateError('No active simctl recording session exists.');
    }

    try {
      process.kill(ProcessSignal.sigint);
      await process.exitCode.timeout(_stopTimeout);
      final hasOutput = await cockpitWaitForNonEmptyFile(
        outputFile,
        timeout: _stopTimeout,
        pollInterval: _finalizationPollInterval,
      );
      if (!hasOutput) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          failureReason: 'simctl recording output file was missing or empty.',
        );
      }
      final finalized = await _waitForFinalizedOutput(
        outputFile,
        expectedDurationMs: stopwatch?.elapsedMilliseconds ?? 0,
      );
      if (!finalized) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          failureReason:
              'simctl recording output did not finalize to a stable duration.',
        );
      }

      stopwatch?.stop();
      return CockpitRecordingResult(
        state: CockpitRecordingState.completed,
        purpose: request.purpose,
        recordingKind: CockpitRecordingKind.nativeScreen,
        artifact: cockpitRecordingArtifactForName(request.name),
        durationMs: stopwatch?.elapsedMilliseconds,
        sourceFilePath: outputFile.path,
      );
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      return CockpitRecordingResult(
        state: CockpitRecordingState.failed,
        purpose: request.purpose,
        recordingKind: CockpitRecordingKind.nativeScreen,
        failureReason: 'simctl recording did not stop before timeout.',
      );
    } finally {
      await _stderrSubscription?.cancel();
      _process = null;
      _request = null;
      _outputFile = null;
      _stderrSubscription = null;
      _stopwatch = null;
    }
  }

  Future<bool> _waitForFinalizedOutput(
    File outputFile, {
    required int expectedDurationMs,
  }) async {
    final stableFile = await cockpitWaitForStableFile(
      outputFile,
      timeout: _stopTimeout,
      pollInterval: _finalizationPollInterval,
    );
    if (!stableFile) {
      return false;
    }

    final minimumExpectedDurationMs = expectedDurationMs <= 0
        ? 800
        : (expectedDurationMs * 0.7).round().clamp(800, expectedDurationMs);
    final deadline = DateTime.now().add(_stopTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final probe = await _probeRecordingTimeline(outputFile.path);
      if (probe == null) {
        return true;
      }
      if (probe.durationMs >= minimumExpectedDurationMs ||
          _looksUsableForSimulatorAcceptance(probe)) {
        return true;
      }
      await Future<void>.delayed(_finalizationPollInterval);
    }

    final finalProbe = await _probeRecordingTimeline(outputFile.path);
    if (finalProbe == null) {
      return true;
    }
    return finalProbe.durationMs >= minimumExpectedDurationMs ||
        _looksUsableForSimulatorAcceptance(finalProbe);
  }

  bool _looksUsableForSimulatorAcceptance(
    _CockpitRecordingTimelineProbe probe,
  ) {
    final hasEnoughDuration = probe.durationMs >= 1200;
    final hasEnoughFrames = (probe.frameCount ?? 0) >= 20;
    return hasEnoughDuration && hasEnoughFrames;
  }

  Future<_CockpitRecordingTimelineProbe?> _probeRecordingTimeline(
    String path,
  ) async {
    try {
      final result = await _processRunner(_ffprobeExecutable, <String>[
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_streams',
        '-show_format',
        path,
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
      int? frameCount;
      final streams = decoded['streams'];
      if (streams is List<Object?>) {
        for (final stream in streams) {
          if (stream is! Map<Object?, Object?>) {
            continue;
          }
          if (stream['codec_type'] != 'video') {
            continue;
          }
          final frameValue = stream['nb_frames'];
          if (frameValue is String) {
            frameCount = int.tryParse(frameValue);
          } else if (frameValue is int) {
            frameCount = frameValue;
          }
          break;
        }
      }
      return _CockpitRecordingTimelineProbe(
        durationMs: (durationSeconds * 1000).round(),
        frameCount: frameCount,
      );
    } on FormatException {
      return null;
    } on ProcessException {
      return null;
    }
  }
}

final class _CockpitRecordingTimelineProbe {
  const _CockpitRecordingTimelineProbe({
    required this.durationMs,
    required this.frameCount,
  });

  final int durationMs;
  final int? frameCount;
}
