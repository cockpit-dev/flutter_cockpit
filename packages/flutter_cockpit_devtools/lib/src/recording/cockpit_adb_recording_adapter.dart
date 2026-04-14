import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_host_recording_adapter.dart';

bool cockpitHasActiveAdbRecordingSession(String deviceId) {
  return cockpitHasActiveHostRecordingSession(_adbSessionCacheKey(deviceId));
}

final class CockpitAdbRecordingAdapter implements CockpitHostRecordingAdapter {
  CockpitAdbRecordingAdapter({
    required String deviceId,
    String executable = 'adb',
    CockpitRecordingProcessStarter processStarter = Process.start,
    CockpitRecordingProcessRunner processRunner = Process.run,
    CockpitRecordingTempFileFactory tempFileFactory =
        cockpitCreateRecordingTempFile,
    Duration startupTimeout = const Duration(seconds: 3),
    Duration stopTimeout = const Duration(seconds: 10),
  })  : _deviceId = deviceId,
        _executable = executable,
        _processStarter = processStarter,
        _processRunner = processRunner,
        _tempFileFactory = tempFileFactory,
        _startupTimeout = startupTimeout,
        _stopTimeout = stopTimeout;

  final String _deviceId;
  final String _executable;
  final CockpitRecordingProcessStarter _processStarter;
  final CockpitRecordingProcessRunner _processRunner;
  final CockpitRecordingTempFileFactory _tempFileFactory;
  final Duration _startupTimeout;
  final Duration _stopTimeout;

  Process? _process;
  CockpitRecordingRequest? _request;
  String? _remotePath;
  Stopwatch? _stopwatch;

  String get _sessionCacheKey => _adbSessionCacheKey(_deviceId);

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    if (_process != null ||
        cockpitReadActiveHostRecordingSession(_sessionCacheKey) != null) {
      throw StateError('An adb recording is already active.');
    }

    final remotePath =
        '/sdcard/Download/${cockpitRecordingFileName(request.name)}';
    final process = await _processStarter(_executable, <String>[
      '-s',
      _deviceId,
      'shell',
      'screenrecord',
      remotePath,
    ]);

    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());

    try {
      await _waitForRemoteStart(process);
    } on Object {
      process.kill(ProcessSignal.sigkill);
      rethrow;
    }

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
    final remotePath = session?.outputFile.path;
    final stopwatch = session?.stopwatch;
    if (process == null || request == null || remotePath == null) {
      throw StateError('No active adb recording session exists.');
    }

    final outputFile = await _tempFileFactory(
      cockpitRecordingFileName(request.name),
    );
    outputFile.parent.createSync(recursive: true);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    try {
      final stopRequested = await _requestRemoteStop();
      if (!stopRequested) {
        process.kill(ProcessSignal.sigint);
      }
      await process.exitCode.timeout(_stopTimeout);

      final pullResult = await _processRunner(_executable, <String>[
        '-s',
        _deviceId,
        'pull',
        remotePath,
        outputFile.path,
      ]);
      if (pullResult.exitCode != 0) {
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          requestedMode: request.mode,
          requestedLayer: request.layer,
          effectiveLayer: CockpitRecordingLayer.system,
          failureReason:
              'adb pull failed: ${pullResult.stderr ?? pullResult.stdout}',
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

      stopwatch?.stop();
      return CockpitRecordingResult(
        state: CockpitRecordingState.completed,
        purpose: request.purpose,
        recordingKind: CockpitRecordingKind.nativeScreen,
        requestedMode: request.mode,
        requestedLayer: request.layer,
        effectiveLayer: CockpitRecordingLayer.system,
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
        requestedMode: request.mode,
        requestedLayer: request.layer,
        effectiveLayer: CockpitRecordingLayer.system,
        failureReason: 'adb recording did not stop before timeout.',
      );
    } finally {
      await _cleanupRemoteFile(remotePath);
      cockpitClearActiveHostRecordingSession(_sessionCacheKey);
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
      );
    }
    return cockpitReadActiveHostRecordingSession(_sessionCacheKey);
  }

  Future<void> _cleanupRemoteFile(String remotePath) async {
    try {
      await _processRunner(_executable, <String>[
        '-s',
        _deviceId,
        'shell',
        'rm',
        remotePath,
      ]);
    } on Object {
      // Remote cleanup is best-effort after the host artifact has been pulled.
    }
  }

  Future<bool> _requestRemoteStop() async {
    final killallResult = await _processRunner(_executable, <String>[
      '-s',
      _deviceId,
      'shell',
      'killall',
      '-s',
      'INT',
      'screenrecord',
    ]);
    if (killallResult.exitCode == 0) {
      return true;
    }

    final pkillResult = await _processRunner(_executable, <String>[
      '-s',
      _deviceId,
      'shell',
      'pkill',
      '-l',
      'INT',
      'screenrecord',
    ]);
    return pkillResult.exitCode == 0;
  }

  Future<void> _waitForRemoteStart(Process process) async {
    final deadline = DateTime.now().add(_startupTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _isRemoteScreenrecordRunning()) {
        return;
      }

      final exitCode = await process.exitCode.timeout(
        const Duration(milliseconds: 100),
        onTimeout: () => -1,
      );
      if (exitCode != -1) {
        throw StateError(
          'adb screenrecord exited before startup (exitCode=$exitCode).',
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    final exitCode = await process.exitCode.timeout(
      Duration.zero,
      onTimeout: () => -1,
    );
    if (exitCode == -1) {
      return;
    }

    throw TimeoutException('adb screenrecord did not appear on device.');
  }

  Future<bool> _isRemoteScreenrecordRunning() async {
    final pidofResult = await _processRunner(_executable, <String>[
      '-s',
      _deviceId,
      'shell',
      'pidof',
      'screenrecord',
    ]);
    if (pidofResult.exitCode == 0) {
      return true;
    }

    final psResult = await _processRunner(_executable, <String>[
      '-s',
      _deviceId,
      'shell',
      'ps',
      '-A',
    ]);
    if (psResult.exitCode != 0) {
      return false;
    }

    return '${psResult.stdout}'.contains('screenrecord');
  }
}

String _adbSessionCacheKey(String deviceId) => 'adb:$deviceId';
