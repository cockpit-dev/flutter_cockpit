import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_host_recording_adapter.dart';

final class CockpitLinuxDisplayConfig {
  const CockpitLinuxDisplayConfig({
    required this.display,
    required this.captureSize,
  });

  final String display;
  final String captureSize;
}

typedef CockpitLinuxDisplayConfigResolver = Future<CockpitLinuxDisplayConfig>
    Function();

final class CockpitLinuxRecordingAdapter
    implements CockpitHostRecordingAdapter {
  CockpitLinuxRecordingAdapter({
    required String appId,
    String ffmpegExecutable = 'ffmpeg',
    String? windowActivatorExecutable = 'wmctrl',
    CockpitRecordingProcessStarter processStarter = Process.start,
    CockpitRecordingProcessRunner processRunner = Process.run,
    CockpitRecordingProcessRunner? ffprobeProcessRunner,
    CockpitRecordingTempFileFactory tempFileFactory =
        cockpitCreateRecordingTempFile,
    CockpitLinuxDisplayConfigResolver? displayConfigResolver,
    Duration startupTimeout = const Duration(seconds: 12),
    Duration stopTimeout = const Duration(seconds: 10),
    Duration finalizationPollInterval = const Duration(milliseconds: 100),
    Duration activationSettleDelay = const Duration(milliseconds: 250),
  })  : _appId = appId,
        _ffmpegExecutable = ffmpegExecutable,
        _windowActivatorExecutable = windowActivatorExecutable,
        _processStarter = processStarter,
        _processRunner = processRunner,
        _ffprobeProcessRunner = ffprobeProcessRunner ?? processRunner,
        _tempFileFactory = tempFileFactory,
        _displayConfigResolver = displayConfigResolver ??
            (() => _resolveDisplayConfig(processRunner)),
        _startupTimeout = startupTimeout,
        _stopTimeout = stopTimeout,
        _finalizationPollInterval = finalizationPollInterval,
        _activationSettleDelay = activationSettleDelay;

  final String _appId;
  final String _ffmpegExecutable;
  final String? _windowActivatorExecutable;
  final CockpitRecordingProcessStarter _processStarter;
  final CockpitRecordingProcessRunner _processRunner;
  final CockpitRecordingProcessRunner _ffprobeProcessRunner;
  final CockpitRecordingTempFileFactory _tempFileFactory;
  final CockpitLinuxDisplayConfigResolver _displayConfigResolver;
  final Duration _startupTimeout;
  final Duration _stopTimeout;
  final Duration _finalizationPollInterval;
  final Duration _activationSettleDelay;

  Process? _process;
  CockpitRecordingRequest? _request;
  File? _outputFile;
  StreamSubscription<String>? _stderrSubscription;
  Stopwatch? _stopwatch;

  String get _sessionCacheKey => 'linux:$_appId';

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    if (_process != null ||
        cockpitReadActiveHostRecordingSession(_sessionCacheKey) != null) {
      throw StateError('A Linux recording is already active.');
    }

    await _bestEffortActivateApp();
    final displayConfig = await _displayConfigResolver();

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
      'x11grab',
      '-framerate',
      '30',
      '-draw_mouse',
      '1',
      '-video_size',
      displayConfig.captureSize,
      '-i',
      '${displayConfig.display}+0,0',
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
      throw StateError('No active Linux recording session exists.');
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
          failureReason: 'Linux recording output file was missing or empty.',
        );
      }
      final finalized = await _waitForFinalizedOutput(outputFile);
      if (!finalized) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          failureReason:
              'Linux recording output did not finalize to a stable duration.',
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
        failureReason: 'Linux recording did not stop before timeout.',
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
    final executable = _windowActivatorExecutable;
    if (executable == null || executable.isEmpty) {
      return;
    }
    try {
      final result = await _processRunner(
        executable,
        <String>['-xa', _appId],
      ).timeout(_startupTimeout);
      if (result.exitCode == 0 && _activationSettleDelay > Duration.zero) {
        await Future<void>.delayed(_activationSettleDelay);
      }
    } on Object {
      // Activation is best-effort only on Linux hosts.
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

  static Future<CockpitLinuxDisplayConfig> _resolveDisplayConfig(
    CockpitRecordingProcessRunner processRunner,
  ) async {
    final display = Platform.environment['DISPLAY'];
    if (display == null || display.isEmpty) {
      throw StateError(
        'Linux recording requires DISPLAY to be set for x11grab.',
      );
    }

    final xdpyinfoResult = await processRunner('xdpyinfo', <String>[]);
    if (xdpyinfoResult.exitCode == 0) {
      final match = RegExp(
        r'dimensions:\s+([0-9]+x[0-9]+)\s+pixels',
      ).firstMatch('${xdpyinfoResult.stdout}');
      if (match != null) {
        return CockpitLinuxDisplayConfig(
          display: display,
          captureSize: match.group(1)!,
        );
      }
    }

    final xrandrResult = await processRunner('xrandr', <String>[]);
    if (xrandrResult.exitCode == 0) {
      final match = RegExp(r'([0-9]+x[0-9]+)\s+[0-9.]+\*').firstMatch(
        '${xrandrResult.stdout}',
      );
      if (match != null) {
        return CockpitLinuxDisplayConfig(
          display: display,
          captureSize: match.group(1)!,
        );
      }
    }

    throw StateError(
        'Unable to resolve Linux display dimensions for $display.');
  }
}

final class _CockpitRecordingTimelineProbe {
  const _CockpitRecordingTimelineProbe({required this.durationMs});

  final int durationMs;
}
