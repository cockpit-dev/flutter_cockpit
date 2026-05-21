import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../platform/macos/cockpit_macos_window_target.dart';
import 'cockpit_host_recording_adapter.dart';

final class CockpitMacosRecordingAdapter
    implements CockpitHostRecordingAdapter {
  CockpitMacosRecordingAdapter({
    required String appId,
    String ffmpegExecutable = 'ffmpeg',
    String osascriptExecutable = 'osascript',
    CockpitRecordingProcessStarter processStarter = Process.start,
    CockpitRecordingProcessRunner processRunner = Process.run,
    CockpitRecordingProcessRunner? ffprobeProcessRunner,
    CockpitRecordingTempFileFactory tempFileFactory =
        cockpitCreateRecordingTempFile,
    CockpitMacosWindowTargetResolver windowTargetResolver =
        cockpitResolveMacosWindowTarget,
    Duration startupTimeout = const Duration(seconds: 12),
    Duration startupEvidenceTimeout = const Duration(seconds: 2),
    Duration stopTimeout = const Duration(seconds: 10),
    Duration finalizationPollInterval = const Duration(milliseconds: 100),
    Duration activationSettleDelay = const Duration(milliseconds: 350),
  })  : _appId = appId,
        _ffmpegExecutable = ffmpegExecutable,
        _osascriptExecutable = osascriptExecutable,
        _processStarter = processStarter,
        _processRunner = processRunner,
        _ffprobeProcessRunner = ffprobeProcessRunner ?? processRunner,
        _tempFileFactory = tempFileFactory,
        _windowTargetResolver = windowTargetResolver,
        _startupTimeout = startupTimeout,
        _startupEvidenceTimeout = startupEvidenceTimeout,
        _stopTimeout = stopTimeout,
        _finalizationPollInterval = finalizationPollInterval,
        _activationSettleDelay = activationSettleDelay;

  final String _appId;
  final String _ffmpegExecutable;
  final String _osascriptExecutable;
  final CockpitRecordingProcessStarter _processStarter;
  final CockpitRecordingProcessRunner _processRunner;
  final CockpitRecordingProcessRunner _ffprobeProcessRunner;
  final CockpitRecordingTempFileFactory _tempFileFactory;
  final CockpitMacosWindowTargetResolver _windowTargetResolver;
  final Duration _startupTimeout;
  final Duration _startupEvidenceTimeout;
  final Duration _stopTimeout;
  final Duration _finalizationPollInterval;
  final Duration _activationSettleDelay;

  static const Set<String> _browserAppIds = <String>{
    'com.google.Chrome',
    'com.microsoft.edgemac',
    'org.mozilla.firefox',
  };

  Process? _process;
  CockpitRecordingRequest? _request;
  File? _outputFile;
  StreamSubscription<String>? _stderrSubscription;
  Stopwatch? _stopwatch;

  String get _sessionCacheKey => 'macos:$_appId';

  bool get _usesBrowserHostCapture => _browserAppIds.contains(_appId);

  Duration get _effectiveStartupEvidenceTimeout {
    if (!_usesBrowserHostCapture) {
      return _startupEvidenceTimeout;
    }
    const browserMinimum = Duration(seconds: 6);
    return _startupEvidenceTimeout >= browserMinimum
        ? _startupEvidenceTimeout
        : browserMinimum;
  }

  Duration get _effectiveActivationSettleDelay {
    if (!_usesBrowserHostCapture) {
      return _activationSettleDelay;
    }
    const browserMinimum = Duration(seconds: 1);
    return _activationSettleDelay >= browserMinimum
        ? _activationSettleDelay
        : browserMinimum;
  }

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    if (_process != null ||
        cockpitReadActiveHostRecordingSession(_sessionCacheKey) != null) {
      throw StateError('A macOS recording is already active.');
    }

    await _activateApp();
    if (_effectiveActivationSettleDelay > Duration.zero) {
      await Future<void>.delayed(_effectiveActivationSettleDelay);
    }

    final inputSpecifier = await _resolveScreenInputSpecifier();
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
      'avfoundation',
      '-framerate',
      '30',
      '-capture_cursor',
      '1',
      '-i',
      inputSpecifier,
      '-vf',
      'scale=trunc(iw/2)*2:trunc(ih/2)*2,format=yuv420p',
      '-c:v',
      'libx264',
      '-movflags',
      '+faststart',
      outputFile.path,
    ]);

    unawaited(process.stdout.drain<void>());

    final startupCompleter = Completer<void>();
    final recentStderrLines = <String>[];
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
      _appendRecentStderrLine(recentStderrLines, line);
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
      final hasOutputEvidence = await cockpitWaitForNonEmptyFile(
        outputFile,
        timeout: _effectiveStartupEvidenceTimeout,
        pollInterval: _finalizationPollInterval,
      );
      if (!hasOutputEvidence && _usesBrowserHostCapture) {
        // Browser-host capture can stay silent until stop/finalization even
        // when ffmpeg has attached successfully to the screen input.
      } else if (!hasOutputEvidence) {
        await stderrSubscription.cancel();
        process.kill(ProcessSignal.sigkill);
        throw StateError(
          _buildStartupFailureMessage(recentStderrLines),
        );
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
      throw StateError('No active macOS recording session exists.');
    }

    try {
      final didStopGracefully = await _requestGracefulStop(process);
      if (!didStopGracefully) {
        process.kill(ProcessSignal.sigint);
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
          failureReason: 'macOS recording output file was missing or empty.',
        );
      }
      final finalized = await _waitForFinalizedOutput(outputFile);
      if (!finalized) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          failureReason:
              'macOS recording output did not finalize to a stable duration.',
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
        failureReason: 'macOS recording did not stop before timeout.',
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

  Future<void> _activateApp() async {
    final result = await _processRunner(_osascriptExecutable, <String>[
      '-e',
      'tell application id "$_appId" to activate',
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to activate macOS app $_appId: ${result.stderr ?? result.stdout}',
      );
    }
  }

  Future<String> _resolveScreenInputSpecifier() async {
    final result = await _processRunner(_ffmpegExecutable, <String>[
      '-f',
      'avfoundation',
      '-list_devices',
      'true',
      '-i',
      '',
    ]);
    final output = <String>[
      '${result.stdout}',
      '${result.stderr}',
    ].join('\n');
    final screens = _parseCaptureScreens(output);
    if (screens.isEmpty) {
      throw StateError('Unable to resolve a macOS capture screen input.');
    }
    final selectedScreen = await _selectCaptureScreen(screens);
    return '${selectedScreen.index}:none';
  }

  Future<_CockpitMacosCaptureScreen> _selectCaptureScreen(
    List<_CockpitMacosCaptureScreen> screens,
  ) async {
    if (screens.length == 1) {
      return screens.first;
    }

    final screensWithBounds =
        screens.where((screen) => screen.hasBounds).toList(growable: false);
    if (screensWithBounds.isEmpty) {
      return screens.first;
    }

    final windowTarget = await _tryResolveWindowTarget();
    if (windowTarget == null) {
      return screens.first;
    }

    _CockpitMacosCaptureScreen? bestScreen;
    var bestOverlap = 0;
    for (final screen in screensWithBounds) {
      final overlap = screen.overlapAreaWith(windowTarget);
      if (overlap > bestOverlap) {
        bestScreen = screen;
        bestOverlap = overlap;
      }
    }
    if (bestScreen != null && bestOverlap > 0) {
      return bestScreen;
    }

    final centerX = windowTarget.left + (windowTarget.width / 2.0);
    final centerY = windowTarget.top + (windowTarget.height / 2.0);
    for (final screen in screensWithBounds) {
      if (screen.containsPoint(centerX, centerY)) {
        return screen;
      }
    }

    var nearestScreen = screensWithBounds.first;
    var nearestDistance =
        nearestScreen.squaredDistanceToPoint(centerX, centerY);
    for (final screen in screensWithBounds.skip(1)) {
      final distance = screen.squaredDistanceToPoint(centerX, centerY);
      if (distance < nearestDistance) {
        nearestScreen = screen;
        nearestDistance = distance;
      }
    }
    return nearestScreen;
  }

  Future<CockpitMacosWindowTarget?> _tryResolveWindowTarget() async {
    try {
      return await _windowTargetResolver(
        appId: _appId,
        osascriptExecutable: _osascriptExecutable,
        processRunner: _processRunner,
        timeout: _startupTimeout,
        activationSettleDelay: Duration.zero,
      );
    } on Object {
      return null;
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

  void _appendRecentStderrLine(List<String> buffer, String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }
    buffer.add(trimmed);
    if (buffer.length > 8) {
      buffer.removeAt(0);
    }
  }

  String _buildStartupFailureMessage(List<String> recentStderrLines) {
    const prefix =
        'ffmpeg never confirmed macOS screen capture startup or produced output. '
        'Ensure Screen Recording permission is granted to the terminal, Dart, and ffmpeg on this host.';
    if (recentStderrLines.isEmpty) {
      return prefix;
    }
    return '$prefix Recent ffmpeg output: ${recentStderrLines.join(' | ')}';
  }
}

List<_CockpitMacosCaptureScreen> _parseCaptureScreens(String output) {
  return _captureScreenPattern.allMatches(output).map((match) {
    return _CockpitMacosCaptureScreen(
      index: int.parse(match.group(1)!),
      width: int.tryParse(match.group(2) ?? ''),
      height: int.tryParse(match.group(3) ?? ''),
      left: int.tryParse(match.group(4) ?? ''),
      top: int.tryParse(match.group(5) ?? ''),
    );
  }).toList(growable: false);
}

final RegExp _captureScreenPattern = RegExp(
  r'\[([0-9]+)\]\s+Capture screen(?:\s+\d+)?(?:\s+(\d+)x(\d+)\s+@\s+(-?\d+),(-?\d+))?',
  multiLine: true,
);

final class _CockpitMacosCaptureScreen {
  const _CockpitMacosCaptureScreen({
    required this.index,
    this.width,
    this.height,
    this.left,
    this.top,
  });

  final int index;
  final int? width;
  final int? height;
  final int? left;
  final int? top;

  bool get hasBounds =>
      width != null &&
      height != null &&
      left != null &&
      top != null &&
      width! > 0 &&
      height! > 0;

  int get _right => left! + width!;
  int get _bottom => top! + height!;

  bool containsPoint(double x, double y) {
    if (!hasBounds) {
      return false;
    }
    return x >= left! && x < _right && y >= top! && y < _bottom;
  }

  int overlapAreaWith(CockpitMacosWindowTarget target) {
    if (!hasBounds) {
      return 0;
    }
    final overlapLeft = math.max(left!, target.left);
    final overlapTop = math.max(top!, target.top);
    final overlapRight = math.min(_right, target.left + target.width);
    final overlapBottom = math.min(_bottom, target.top + target.height);
    final overlapWidth = overlapRight - overlapLeft;
    final overlapHeight = overlapBottom - overlapTop;
    if (overlapWidth <= 0 || overlapHeight <= 0) {
      return 0;
    }
    return overlapWidth * overlapHeight;
  }

  double squaredDistanceToPoint(double x, double y) {
    if (!hasBounds) {
      return double.infinity;
    }
    final dx = x < left!
        ? left! - x
        : x > _right
            ? x - _right
            : 0.0;
    final dy = y < top!
        ? top! - y
        : y > _bottom
            ? y - _bottom
            : 0.0;
    return (dx * dx) + (dy * dy);
  }
}

final class _CockpitRecordingTimelineProbe {
  const _CockpitRecordingTimelineProbe({required this.durationMs});

  final int durationMs;
}
