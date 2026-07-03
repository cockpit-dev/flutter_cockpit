import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import 'cockpit_host_recording_adapter.dart';

const int _screenrecordTimeLimitSeconds = 180;

bool cockpitHasActiveAdbRecordingSession(String deviceId) {
  return cockpitHasActiveHostRecordingSession(_adbSessionCacheKey(deviceId));
}

Future<bool> cockpitHasLiveAdbRecordingSession(
  String deviceId, {
  String executable = 'adb',
  CockpitRecordingProcessRunner? processRunner,
  CockpitPidLivenessChecker pidLivenessChecker =
      cockpitDefaultPidLivenessChecker,
}) async {
  final sessionKey = _adbSessionCacheKey(deviceId);
  if (cockpitReadActiveHostRecordingSession(sessionKey) != null) {
    return true;
  }
  final persisted = cockpitReadPersistedHostRecordingSession(sessionKey);
  if (persisted == null) {
    return cockpitHasActiveHostRecordingSession(sessionKey);
  }
  if (await _isRemoteScreenrecordRunningOnDevice(
        executable: executable,
        deviceId: deviceId,
        processRunner: processRunner,
        timeout: const Duration(seconds: 2),
      ) ==
      true) {
    return true;
  }
  if (await pidLivenessChecker(persisted.pid)) {
    return true;
  }
  cockpitClearPersistedHostRecordingSession(sessionKey);
  return false;
}

final class CockpitAdbRecordingAdapter implements CockpitHostRecordingAdapter {
  CockpitAdbRecordingAdapter({
    required String deviceId,
    String executable = 'adb',
    CockpitRecordingProcessStarter processStarter =
        cockpitStartDetachedRecordingProcess,
    CockpitRecordingProcessRunner? processRunner,
    CockpitRecordingTempFileFactory tempFileFactory =
        cockpitCreateRecordingTempFile,
    Duration startupTimeout = const Duration(seconds: 3),
    Duration stopTimeout = const Duration(seconds: 10),
    CockpitPidSignalSender pidSignalSender = Process.killPid,
    CockpitPidLivenessChecker pidLivenessChecker =
        cockpitDefaultPidLivenessChecker,
  }) : _deviceId = deviceId,
       _executable = executable,
       _processStarter = processStarter,
       _processRunner = processRunner,
       _tempFileFactory = tempFileFactory,
       _startupTimeout = startupTimeout,
       _stopTimeout = stopTimeout,
       _pidSignalSender = pidSignalSender,
       _pidLivenessChecker = pidLivenessChecker;

  final String _deviceId;
  final String _executable;
  final CockpitRecordingProcessStarter _processStarter;
  final CockpitRecordingProcessRunner? _processRunner;
  final CockpitRecordingTempFileFactory _tempFileFactory;
  final Duration _startupTimeout;
  final Duration _stopTimeout;
  final CockpitPidSignalSender _pidSignalSender;
  final CockpitPidLivenessChecker _pidLivenessChecker;

  Process? _process;
  CockpitRecordingRequest? _request;
  String? _remotePath;
  Stopwatch? _stopwatch;

  String get _sessionCacheKey => _adbSessionCacheKey(_deviceId);

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    if (_process != null || await _restoreableSessionExists()) {
      throw StateError('An adb recording is already active.');
    }

    final remotePath =
        '/sdcard/Download/${cockpitRecordingFileName(request.name)}';
    final process = await _processStarter(_executable, <String>[
      '-s',
      _deviceId,
      'shell',
      'screenrecord',
      // screenrecord stops itself at its time limit; pin the default so the
      // behavior is deterministic across Android versions and detectable.
      '--time-limit',
      '$_screenrecordTimeLimitSeconds',
      remotePath,
    ]);

    final stdoutSubscription = process.stdout.listen((_) {});
    final stderrSubscription = process.stderr.listen((_) {});

    try {
      await _waitForRemoteStart(process);
    } on Object {
      await cockpitCancelRecordingSubscription(stdoutSubscription);
      await cockpitCancelRecordingSubscription(stderrSubscription);
      process.kill(ProcessSignal.sigkill);
      rethrow;
    }

    final startedAt = DateTime.now().toUtc();
    await cockpitPersistHostRecordingSession(
      _sessionCacheKey,
      CockpitHostRecordingPersistedSession(
        pid: process.pid,
        request: request,
        outputFilePath: remotePath,
        remotePath: remotePath,
        startedAt: startedAt,
      ),
    );
    await cockpitCancelRecordingSubscription(stdoutSubscription);
    await cockpitCancelRecordingSubscription(stderrSubscription);

    _process = process;
    _request = request;
    _remotePath = remotePath;
    _stopwatch = Stopwatch()..start();
    cockpitStoreActiveHostRecordingSession(
      _sessionCacheKey,
      CockpitHostRecordingRuntimeSession(
        process: process,
        request: request,
        outputFile: File(remotePath),
        stderrSubscription: null,
        stopwatch: _stopwatch,
        startedAt: startedAt,
        remotePath: remotePath,
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
    final remotePath = session?.remotePath ?? session?.outputFile.path;
    final stopwatch = session?.stopwatch;
    if (request == null || remotePath == null) {
      final persistedSession = cockpitReadPersistedHostRecordingSession(
        _sessionCacheKey,
      );
      if (persistedSession == null) {
        throw StateError('No active adb recording session exists.');
      }
      return _stopPersistedRecording(persistedSession);
    }

    final outputFile = await _tempFileFactory(
      cockpitRecordingFileName(request.name),
    );
    outputFile.parent.createSync(recursive: true);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    try {
      // Stop the clock before the stop handshake and pull so the duration
      // (and the time-limit attribution below) reflects recorded footage,
      // not stop/pull overhead.
      stopwatch?.stop();
      final durationMs = stopwatch?.elapsedMilliseconds ?? _durationMs(session);
      final stopRequested = await _requestRemoteStop();
      if (!stopRequested && process != null) {
        process.kill(ProcessSignal.sigint);
      }
      if (!await _waitForRemoteScreenrecordExit() && !stopRequested) {
        throw TimeoutException('adb screenrecord did not stop.');
      }

      final pullFailure = await _pullRecordingArtifact(
        remotePath: remotePath,
        outputFile: outputFile,
      );
      if (pullFailure != null) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          requestedMode: request.mode,
          requestedLayer: request.layer,
          effectiveLayer: CockpitRecordingLayer.system,
          failureReason: pullFailure,
        );
      }

      final hasOutput = await cockpitWaitForNonEmptyFile(
        outputFile,
        timeout: _stopTimeout,
      );
      if (!hasOutput) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          requestedMode: request.mode,
          requestedLayer: request.layer,
          effectiveLayer: CockpitRecordingLayer.system,
          failureReason: 'adb recording output file was missing or empty.',
        );
      }

      cockpitClearPersistedHostRecordingSession(_sessionCacheKey);
      return CockpitRecordingResult(
        state: CockpitRecordingState.completed,
        purpose: request.purpose,
        recordingKind: CockpitRecordingKind.nativeScreen,
        requestedMode: request.mode,
        requestedLayer: request.layer,
        effectiveLayer: CockpitRecordingLayer.system,
        fallbackReason:
            durationMs != null && _reachedScreenrecordLimit(durationMs)
            ? 'androidScreenrecordTimeLimitReached'
            : null,
        artifact: cockpitRecordingArtifactForName(request.name),
        durationMs: durationMs,
        sourceFilePath: outputFile.path,
      );
    } on TimeoutException {
      process?.kill(ProcessSignal.sigkill);
      return CockpitRecordingResult(
        state: CockpitRecordingState.failed,
        purpose: request.purpose,
        recordingKind: CockpitRecordingKind.nativeScreen,
        requestedMode: request.mode,
        requestedLayer: request.layer,
        effectiveLayer: CockpitRecordingLayer.system,
        failureReason: 'adb recording did not stop before timeout.',
      );
    } finally {
      await _cleanupRemoteFile(remotePath);
      cockpitClearActiveHostRecordingSession(_sessionCacheKey);
      cockpitClearPersistedHostRecordingSession(_sessionCacheKey);
      _process = null;
      _request = null;
      _remotePath = null;
      _stopwatch = null;
    }
  }

  CockpitHostRecordingRuntimeSession? get _currentSessionState {
    final process = _process;
    final request = _request;
    final remotePath = _remotePath;
    if (process != null && request != null && remotePath != null) {
      return CockpitHostRecordingRuntimeSession(
        process: process,
        request: request,
        outputFile: File(remotePath),
        stderrSubscription: null,
        stopwatch: _stopwatch,
        remotePath: remotePath,
      );
    }
    return cockpitReadActiveHostRecordingSession(_sessionCacheKey);
  }

  Future<CockpitRecordingResult> _stopPersistedRecording(
    CockpitHostRecordingPersistedSession session,
  ) async {
    final remotePath = session.remotePath ?? session.outputFilePath;
    final outputFile = await _tempFileFactory(
      cockpitRecordingFileName(session.request.name),
    );
    outputFile.parent.createSync(recursive: true);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    try {
      // Measure before the stop handshake and pull so the duration (and the
      // time-limit attribution below) reflects recorded footage only.
      final durationMs = DateTime.now()
          .toUtc()
          .difference(session.startedAt)
          .inMilliseconds;
      final stopRequested = await _requestRemoteStop();
      if (!stopRequested) {
        _pidSignalSender(session.pid, ProcessSignal.sigint);
      }
      final stopped = await _waitForRemoteScreenrecordExit();
      if (!stopped && !stopRequested) {
        _pidSignalSender(session.pid, ProcessSignal.sigkill);
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: session.request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          requestedMode: session.request.mode,
          requestedLayer: session.request.layer,
          effectiveLayer: CockpitRecordingLayer.system,
          failureReason: 'adb recording did not stop before timeout.',
        );
      }

      final pullFailure = await _pullRecordingArtifact(
        remotePath: remotePath,
        outputFile: outputFile,
      );
      if (pullFailure != null) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: session.request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          requestedMode: session.request.mode,
          requestedLayer: session.request.layer,
          effectiveLayer: CockpitRecordingLayer.system,
          failureReason: pullFailure,
        );
      }

      final hasOutput = await cockpitWaitForNonEmptyFile(
        outputFile,
        timeout: _stopTimeout,
      );
      if (!hasOutput) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: session.request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          requestedMode: session.request.mode,
          requestedLayer: session.request.layer,
          effectiveLayer: CockpitRecordingLayer.system,
          failureReason: 'adb recording output file was missing or empty.',
        );
      }

      return CockpitRecordingResult(
        state: CockpitRecordingState.completed,
        purpose: session.request.purpose,
        recordingKind: CockpitRecordingKind.nativeScreen,
        requestedMode: session.request.mode,
        requestedLayer: session.request.layer,
        effectiveLayer: CockpitRecordingLayer.system,
        fallbackReason: _reachedScreenrecordLimit(durationMs)
            ? 'androidScreenrecordTimeLimitReached'
            : null,
        artifact: cockpitRecordingArtifactForName(session.request.name),
        durationMs: durationMs,
        sourceFilePath: outputFile.path,
      );
    } finally {
      await _cleanupRemoteFile(remotePath);
      cockpitClearActiveHostRecordingSession(_sessionCacheKey);
    }
  }

  Future<void> _cleanupRemoteFile(String remotePath) async {
    try {
      await _runProcess(_executable, <String>[
        '-s',
        _deviceId,
        'shell',
        'rm',
        remotePath,
      ], timeout: _stopStageTimeout(const Duration(seconds: 3)));
    } on Object {
      // Remote cleanup is best-effort after the host artifact has been pulled.
    }
  }

  Future<String?> _pullRecordingArtifact({
    required String remotePath,
    required File outputFile,
  }) async {
    final deadline = DateTime.now().add(_stopTimeout);
    ProcessResult? lastResult;
    while (true) {
      lastResult = await _runProcess(_executable, <String>[
        '-s',
        _deviceId,
        'pull',
        remotePath,
        outputFile.path,
      ], timeout: _stopStageTimeout(const Duration(seconds: 5)));
      if (lastResult.exitCode == 0 &&
          outputFile.existsSync() &&
          outputFile.lengthSync() > 0) {
        return null;
      }
      if (!DateTime.now().isBefore(deadline)) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return 'adb pull failed: ${lastResult.stderr ?? lastResult.stdout}';
  }

  Future<bool> _requestRemoteStop() async {
    final killallResult = await _runProcess(_executable, <String>[
      '-s',
      _deviceId,
      'shell',
      'killall',
      '-s',
      'INT',
      'screenrecord',
    ], timeout: _stopStageTimeout(const Duration(seconds: 3)));
    if (killallResult.exitCode == 0) {
      return true;
    }

    final pkillResult = await _runProcess(_executable, <String>[
      '-s',
      _deviceId,
      'shell',
      'pkill',
      '-l',
      'INT',
      'screenrecord',
    ], timeout: _stopStageTimeout(const Duration(seconds: 3)));
    return pkillResult.exitCode == 0;
  }

  Future<bool> _waitForRemoteScreenrecordExit() async {
    final deadline = DateTime.now().add(_stopTimeout);
    while (DateTime.now().isBefore(deadline)) {
      // Only a definitive "not running" probe counts as exited. An
      // inconclusive (timed-out) probe must not let stop proceed while
      // screenrecord may still be finalizing the mp4 moov atom.
      if (await _probeRemoteScreenrecordRunning() == false) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return await _probeRemoteScreenrecordRunning() == false;
  }

  Future<bool> _restoreableSessionExists() async {
    final runtime = cockpitReadActiveHostRecordingSession(_sessionCacheKey);
    if (runtime != null) {
      return true;
    }
    final persisted = cockpitReadPersistedHostRecordingSession(
      _sessionCacheKey,
    );
    if (persisted == null) {
      return false;
    }
    if (await _isRemoteScreenrecordRunning() ||
        await _pidLivenessChecker(persisted.pid)) {
      return true;
    }
    cockpitClearPersistedHostRecordingSession(_sessionCacheKey);
    return false;
  }

  int? _durationMs(CockpitHostRecordingRuntimeSession? session) {
    final startedAt = session?.startedAt;
    if (startedAt == null) {
      return null;
    }
    return DateTime.now().toUtc().difference(startedAt).inMilliseconds;
  }

  Future<void> _waitForRemoteStart(Process process) async {
    final deadline = DateTime.now().add(_startupTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _isRemoteScreenrecordRunning()) {
        return;
      }

      final exitCode = await _tryReadProcessExitCode(process);
      if (exitCode != -1) {
        throw StateError(
          'adb screenrecord exited before startup (exitCode=$exitCode).',
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final exitCode = await _tryReadProcessExitCode(process);
    if (exitCode == -1) {
      return;
    }

    throw TimeoutException('adb screenrecord did not appear on device.');
  }

  Future<int> _tryReadProcessExitCode(Process process) async {
    try {
      return await process.exitCode.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () => -1,
      );
    } on StateError {
      return -1;
    }
  }

  Future<bool> _isRemoteScreenrecordRunning() async {
    return await _probeRemoteScreenrecordRunning() ?? false;
  }

  Future<bool?> _probeRemoteScreenrecordRunning() {
    return _isRemoteScreenrecordRunningOnDevice(
      executable: _executable,
      deviceId: _deviceId,
      processRunner: _processRunner,
      timeout: _startupTimeout,
    );
  }

  Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments, {
    required Duration timeout,
  }) {
    final injected = _processRunner;
    if (injected != null) {
      return injected(executable, arguments).timeout(timeout);
    }
    return cockpitRunRecordingProcessWithTimeout(
      executable,
      arguments,
      timeout: timeout,
    );
  }

  Duration _stopStageTimeout(Duration maximum) {
    if (_stopTimeout <= Duration.zero) {
      return maximum;
    }
    return _stopTimeout < maximum ? _stopTimeout : maximum;
  }

  bool _reachedScreenrecordLimit(int durationMs) {
    const toleranceMs = 1500;
    return durationMs >= (_screenrecordTimeLimitSeconds * 1000) - toleranceMs;
  }
}

String _adbSessionCacheKey(String deviceId) => 'adb:$deviceId';

/// Probes whether screenrecord runs on the device. Returns `true` when proven
/// running, `false` when a successful probe proves it absent, and `null` when
/// the probe is inconclusive (adb timed out or `ps` itself failed) so callers
/// can decide whether "unknown" should count as running or stopped.
Future<bool?> _isRemoteScreenrecordRunningOnDevice({
  required String executable,
  required String deviceId,
  required CockpitRecordingProcessRunner? processRunner,
  required Duration timeout,
}) async {
  final ProcessResult pidofResult;
  try {
    pidofResult = await _runAdbProbeProcess(processRunner, executable, <String>[
      '-s',
      deviceId,
      'shell',
      'pidof',
      'screenrecord',
    ], timeout: timeout);
  } on TimeoutException {
    return null;
  }
  if (pidofResult.exitCode == 0) {
    return true;
  }

  // pidof may be missing on older images, so a non-zero exit is not proof of
  // absence; only a successful ps listing is definitive.
  final ProcessResult psResult;
  try {
    psResult = await _runAdbProbeProcess(processRunner, executable, <String>[
      '-s',
      deviceId,
      'shell',
      'ps',
      '-A',
    ], timeout: timeout);
  } on TimeoutException {
    return null;
  }
  if (psResult.exitCode != 0) {
    return null;
  }

  return '${psResult.stdout}'.contains('screenrecord');
}

Future<ProcessResult> _runAdbProbeProcess(
  CockpitRecordingProcessRunner? processRunner,
  String executable,
  List<String> arguments, {
  required Duration timeout,
}) {
  final injected = processRunner;
  if (injected != null) {
    return injected(executable, arguments).timeout(timeout);
  }
  return cockpitRunRecordingProcessWithTimeout(
    executable,
    arguments,
    timeout: timeout,
  );
}
