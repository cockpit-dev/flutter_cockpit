import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_host_recording_adapter.dart';

final class CockpitWindowsRecordingAdapter
    implements CockpitHostRecordingAdapter {
  CockpitWindowsRecordingAdapter({
    required String appId,
    String ffmpegExecutable = 'ffmpeg',
    String powershellExecutable = 'powershell',
    CockpitRecordingProcessStarter processStarter = Process.start,
    CockpitRecordingProcessRunner processRunner = Process.run,
    CockpitRecordingProcessRunner? ffprobeProcessRunner,
    CockpitRecordingTempFileFactory tempFileFactory =
        cockpitCreateRecordingTempFile,
    Duration startupTimeout = const Duration(seconds: 12),
    Duration stopTimeout = const Duration(seconds: 10),
    Duration finalizationPollInterval = const Duration(milliseconds: 100),
    Duration activationSettleDelay = const Duration(milliseconds: 250),
  })  : _appId = appId,
        _ffmpegExecutable = ffmpegExecutable,
        _powershellExecutable = powershellExecutable,
        _processStarter = processStarter,
        _processRunner = processRunner,
        _ffprobeProcessRunner = ffprobeProcessRunner ?? processRunner,
        _tempFileFactory = tempFileFactory,
        _startupTimeout = startupTimeout,
        _stopTimeout = stopTimeout,
        _finalizationPollInterval = finalizationPollInterval,
        _activationSettleDelay = activationSettleDelay;

  final String _appId;
  final String _ffmpegExecutable;
  final String _powershellExecutable;
  final CockpitRecordingProcessStarter _processStarter;
  final CockpitRecordingProcessRunner _processRunner;
  final CockpitRecordingProcessRunner _ffprobeProcessRunner;
  final CockpitRecordingTempFileFactory _tempFileFactory;
  final Duration _startupTimeout;
  final Duration _stopTimeout;
  final Duration _finalizationPollInterval;
  final Duration _activationSettleDelay;

  Process? _process;
  CockpitRecordingRequest? _request;
  File? _outputFile;
  StreamSubscription<String>? _stderrSubscription;
  Stopwatch? _stopwatch;

  String get _sessionCacheKey => 'windows:$_appId';

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    if (_process != null ||
        cockpitReadActiveHostRecordingSession(_sessionCacheKey) != null) {
      throw StateError('A Windows recording is already active.');
    }

    await _bestEffortActivateApp();

    final outputFile = await _tempFileFactory(
      cockpitRecordingFileName(request.name),
    );
    outputFile.parent.createSync(recursive: true);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    final process = await _processStarter(_ffmpegExecutable, <String>[
      '-y',
      '-f',
      'gdigrab',
      '-framerate',
      '30',
      '-draw_mouse',
      '1',
      '-i',
      'desktop',
      '-vf',
      'format=yuv420p',
      '-c:v',
      'libx264',
      '-movflags',
      '+faststart',
      outputFile.path,
    ]);

    unawaited(process.stdout.drain<void>());

    final startupCompleter = Completer<void>();
    var processExited = false;
    unawaited(
      process.exitCode.then((_) {
        processExited = true;
      }),
    );
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (!startupCompleter.isCompleted &&
          (line.contains('Press [q] to stop') || line.contains('Output #0'))) {
        startupCompleter.complete();
      }
    });

    try {
      await Future.any<void>(<Future<void>>[
        startupCompleter.future,
        process.exitCode.then((exitCode) {
          throw StateError(
            'ffmpeg exited before startup (exitCode=$exitCode).',
          );
        }),
      ]).timeout(_startupTimeout);
    } on TimeoutException {
      if (processExited) {
        await stderrSubscription.cancel();
        process.kill(ProcessSignal.sigkill);
        rethrow;
      }
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
    cockpitStoreActiveHostRecordingSession(
      _sessionCacheKey,
      CockpitHostRecordingRuntimeSession(
        process: process,
        request: request,
        outputFile: outputFile,
        stderrSubscription: stderrSubscription,
        stopwatch: _stopwatch,
      ),
    );

    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    final session = _currentSessionState;
    final process = session?.process;
    final request = session?.request;
    final outputFile = session?.outputFile;
    final stopwatch = session?.stopwatch;
    if (process == null || request == null || outputFile == null) {
      throw StateError('No active Windows recording session exists.');
    }

    try {
      final didStopGracefully = await _requestGracefulStop(process);
      if (!didStopGracefully) {
        process.kill(ProcessSignal.sigterm);
        await process.exitCode.timeout(_stopTimeout);
      }

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
          failureReason: 'Windows recording output file was missing or empty.',
        );
      }
      final finalized = await _waitForFinalizedOutput(outputFile);
      if (!finalized) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          failureReason:
              'Windows recording output did not finalize to a stable duration.',
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
        failureReason: 'Windows recording did not stop before timeout.',
      );
    } finally {
      await session?.stderrSubscription?.cancel();
      cockpitClearActiveHostRecordingSession(_sessionCacheKey);
      _process = null;
      _request = null;
      _outputFile = null;
      _stderrSubscription = null;
      _stopwatch = null;
    }
  }

  CockpitHostRecordingRuntimeSession? get _currentSessionState {
    final process = _process;
    final request = _request;
    final outputFile = _outputFile;
    if (process != null && request != null && outputFile != null) {
      return CockpitHostRecordingRuntimeSession(
        process: process,
        request: request,
        outputFile: outputFile,
        stderrSubscription: _stderrSubscription,
        stopwatch: _stopwatch,
      );
    }
    return cockpitReadActiveHostRecordingSession(_sessionCacheKey);
  }

  Future<void> _bestEffortActivateApp() async {
    try {
      await _processRunner(_powershellExecutable, <String>[
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        _activationScript,
        _appId,
        _activationSettleDelay.inMilliseconds.toString(),
      ]).timeout(_startupTimeout);
    } on Object {
      // Activation is best-effort only on desktop hosts.
    }
  }

  Future<bool> _requestGracefulStop(Process process) async {
    try {
      process.stdin.writeln('q');
      await process.stdin.flush();
      await process.exitCode.timeout(_stopTimeout);
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> _waitForFinalizedOutput(File outputFile) async {
    final stableFile = await cockpitWaitForStableFile(
      outputFile,
      timeout: _stopTimeout,
      pollInterval: _finalizationPollInterval,
    );
    if (!stableFile) {
      return false;
    }

    final deadline = DateTime.now().add(_stopTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final probe = await _probeRecordingTimeline(outputFile.path);
      if (probe != null && probe.durationMs > 0) {
        return true;
      }
      await Future<void>.delayed(_finalizationPollInterval);
    }

    final finalProbe = await _probeRecordingTimeline(outputFile.path);
    return finalProbe != null && finalProbe.durationMs > 0;
  }

  Future<_CockpitRecordingTimelineProbe?> _probeRecordingTimeline(
    String path,
  ) async {
    try {
      final result = await _ffprobeProcessRunner('ffprobe', <String>[
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
      return _CockpitRecordingTimelineProbe(
        durationMs: (durationSeconds * 1000).round(),
      );
    } on Object {
      return null;
    }
  }

  static const String _activationScript = r'''
Add-Type -AssemblyName Microsoft.VisualBasic
$appId = $args[0]
$settleMs = [int]$args[1]
try {
  [Microsoft.VisualBasic.Interaction]::AppActivate($appId) | Out-Null
} catch {}
if ($settleMs -gt 0) {
  Start-Sleep -Milliseconds $settleMs
}
''';
}

final class _CockpitRecordingTimelineProbe {
  const _CockpitRecordingTimelineProbe({required this.durationMs});

  final int durationMs;
}
