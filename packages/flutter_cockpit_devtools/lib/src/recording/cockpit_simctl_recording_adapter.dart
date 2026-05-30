import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_host_recording_adapter.dart';

bool cockpitHasActiveSimctlRecordingSession(String deviceId) {
  return _simctlSessionFile(deviceId).existsSync();
}

Future<bool> cockpitHasLiveSimctlRecordingSession(
  String deviceId, {
  CockpitPidLivenessChecker pidLivenessChecker =
      cockpitDefaultPidLivenessChecker,
}) async {
  final file = _simctlSessionFile(deviceId);
  if (!file.existsSync()) {
    return false;
  }
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      await _deleteSimctlSessionFile(file);
      return false;
    }
    final persisted = _PersistedSimctlRecordingSession.fromJson(
      Map<String, Object?>.from(decoded),
    );
    if (await pidLivenessChecker(persisted.pid)) {
      return true;
    }
    await _deleteSimctlSessionFile(file);
    return false;
  } on Object {
    await _deleteSimctlSessionFile(file);
    return false;
  }
}

final class CockpitSimctlRecordingAdapter
    implements CockpitHostRecordingAdapter {
  CockpitSimctlRecordingAdapter({
    required String deviceId,
    String executable = 'xcrun',
    CockpitRecordingProcessStarter processStarter =
        _startDetachedRecordingProcess,
    CockpitRecordingProcessRunner? processRunner,
    CockpitRecordingTempFileFactory tempFileFactory =
        cockpitCreateRecordingTempFile,
    String ffprobeExecutable = 'ffprobe',
    Duration startupTimeout = const Duration(seconds: 5),
    Duration stopTimeout = const Duration(seconds: 10),
    Duration finalizationPollInterval = const Duration(milliseconds: 100),
    CockpitPidSignalSender pidSignalSender = Process.killPid,
    CockpitPidLivenessChecker pidLivenessChecker =
        cockpitDefaultPidLivenessChecker,
  }) : _deviceId = deviceId,
       _executable = executable,
       _processStarter = processStarter,
       _processRunner = processRunner,
       _tempFileFactory = tempFileFactory,
       _ffprobeExecutable = ffprobeExecutable,
       _startupTimeout = startupTimeout,
       _stopTimeout = stopTimeout,
       _finalizationPollInterval = finalizationPollInterval,
       _pidSignalSender = pidSignalSender,
       _pidLivenessChecker = pidLivenessChecker;

  final String _deviceId;
  final String _executable;
  final CockpitRecordingProcessStarter _processStarter;
  final CockpitRecordingProcessRunner? _processRunner;
  final CockpitRecordingTempFileFactory _tempFileFactory;
  final String _ffprobeExecutable;
  final Duration _startupTimeout;
  final Duration _stopTimeout;
  final Duration _finalizationPollInterval;
  final CockpitPidSignalSender _pidSignalSender;
  final CockpitPidLivenessChecker _pidLivenessChecker;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    if (await _restoreableSessionExists()) {
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

    final stdoutSubscription = process.stdout.listen((_) {});

    final startupCompleter = Completer<void>();
    final stderrBuffer = StringBuffer();
    final stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stderrBuffer.writeln(line);
          if (!startupCompleter.isCompleted &&
              line.contains('Recording started')) {
            startupCompleter.complete();
          }
        });

    try {
      await _waitForProcessStartup(
        process: process,
        startupCompleter: startupCompleter,
        stderrBuffer: stderrBuffer,
      );
    } on Object {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
      _pidSignalSender(process.pid, ProcessSignal.sigkill);
      await _waitForProcessExit(process.pid);
      rethrow;
    }

    final startedAt = DateTime.now();
    await _writePersistedSession(
      _PersistedSimctlRecordingSession(
        pid: process.pid,
        request: request,
        outputFilePath: outputFile.path,
        startedAt: startedAt,
      ),
    );
    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();

    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    final persistedSession = await _readPersistedSession();
    if (persistedSession == null) {
      throw StateError('No active simctl recording session exists.');
    }

    try {
      _pidSignalSender(persistedSession.pid, ProcessSignal.sigint);
      final exited = await _waitForProcessExit(persistedSession.pid);
      if (!exited) {
        _pidSignalSender(persistedSession.pid, ProcessSignal.sigkill);
        return CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: persistedSession.request.purpose,
          recordingKind: CockpitRecordingKind.nativeScreen,
          failureReason: 'simctl recording did not stop before timeout.',
        );
      }
      return await _finalizeStoppedRecording(
        request: persistedSession.request,
        outputFile: File(persistedSession.outputFilePath),
        durationMs: DateTime.now()
            .difference(persistedSession.startedAt)
            .inMilliseconds,
      );
    } on TimeoutException {
      _pidSignalSender(persistedSession.pid, ProcessSignal.sigkill);
      return CockpitRecordingResult(
        state: CockpitRecordingState.failed,
        purpose: persistedSession.request.purpose,
        recordingKind: CockpitRecordingKind.nativeScreen,
        failureReason: 'simctl recording did not stop before timeout.',
      );
    } finally {
      await _clearActiveSession();
    }
  }

  Future<CockpitRecordingResult> _finalizeStoppedRecording({
    required CockpitRecordingRequest request,
    required File outputFile,
    required int durationMs,
  }) async {
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
      expectedDurationMs: durationMs,
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

    return CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      purpose: request.purpose,
      recordingKind: CockpitRecordingKind.nativeScreen,
      artifact: cockpitRecordingArtifactForName(request.name),
      durationMs: durationMs,
      sourceFilePath: outputFile.path,
    );
  }

  Future<void> _waitForProcessStartup({
    required Process process,
    required Completer<void> startupCompleter,
    required StringBuffer stderrBuffer,
  }) async {
    final deadline = DateTime.now().add(_startupTimeout);
    const stableRunningWindow = Duration(milliseconds: 750);
    DateTime? runningSince;
    while (DateTime.now().isBefore(deadline)) {
      if (startupCompleter.isCompleted) {
        return;
      }

      final running = await _isProcessRunning(process.pid);
      if (!running) {
        final exitCode = await process.exitCode;
        throw StateError(
          'simctl recordVideo exited before startup (exitCode=$exitCode): ${stderrBuffer.toString().trim()}',
        );
      }

      runningSince ??= DateTime.now();
      await Future<void>.delayed(Duration.zero);
      if (startupCompleter.isCompleted) {
        return;
      }
      if (DateTime.now().difference(runningSince) >= stableRunningWindow) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }

    if (startupCompleter.isCompleted) {
      return;
    }

    if (await _isProcessRunning(process.pid)) {
      return;
    }
    final exitCode = await process.exitCode;

    throw TimeoutException(
      'simctl recordVideo exited before confirming startup (exitCode=$exitCode).',
    );
  }

  Future<bool> _restoreableSessionExists() async {
    final persisted = await _readPersistedSession();
    if (persisted == null) {
      return false;
    }
    if (await _isProcessRunning(persisted.pid)) {
      return true;
    }
    await _clearPersistedSession();
    return false;
  }

  Future<void> _clearActiveSession() async {
    await _clearPersistedSession();
  }

  File get _sessionFile => _simctlSessionFile(_deviceId);

  Future<void> _writePersistedSession(
    _PersistedSimctlRecordingSession session,
  ) async {
    final file = _sessionFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<_PersistedSimctlRecordingSession?> _readPersistedSession() async {
    final file = _sessionFile;
    if (!file.existsSync()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<Object?, Object?>) {
        await _clearPersistedSession();
        return null;
      }
      return _PersistedSimctlRecordingSession.fromJson(
        Map<String, Object?>.from(decoded),
      );
    } on FormatException {
      await _clearPersistedSession();
      return null;
    }
  }

  Future<void> _clearPersistedSession() async {
    await _deleteSimctlSessionFile(_sessionFile);
  }

  Future<bool> _waitForProcessExit(int pid) async {
    final deadline = DateTime.now().add(_stopTimeout);
    while (DateTime.now().isBefore(deadline)) {
      if (!await _isProcessRunning(pid)) {
        return true;
      }
      await Future<void>.delayed(_finalizationPollInterval);
    }
    return !await _isProcessRunning(pid);
  }

  Future<bool> _isProcessRunning(int pid) async {
    return _pidLivenessChecker(pid);
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
        : expectedDurationMs < 800
        ? expectedDurationMs
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
      final result = await _runProcess(_ffprobeExecutable, <String>[
        '-v',
        'error',
        '-print_format',
        'json',
        '-show_streams',
        '-show_format',
        path,
      ], timeout: _stopStageTimeout(const Duration(seconds: 3)));
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
}

File _simctlSessionFile(String deviceId) {
  final sanitizedDeviceId = deviceId.replaceAll(
    RegExp(r'[^A-Za-z0-9._-]+'),
    '_',
  );
  return File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'flutter_cockpit_recording_sessions${Platform.pathSeparator}'
    'simctl_$sanitizedDeviceId.json',
  );
}

final class _PersistedSimctlRecordingSession {
  const _PersistedSimctlRecordingSession({
    required this.pid,
    required this.request,
    required this.outputFilePath,
    required this.startedAt,
  });

  final int pid;
  final CockpitRecordingRequest request;
  final String outputFilePath;
  final DateTime startedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'pid': pid,
    'request': request.toJson(),
    'outputFilePath': outputFilePath,
    'startedAt': startedAt.toUtc().toIso8601String(),
  };

  factory _PersistedSimctlRecordingSession.fromJson(Map<String, Object?> json) {
    return _PersistedSimctlRecordingSession(
      pid: json['pid']! as int,
      request: CockpitRecordingRequest.fromJson(
        Map<String, Object?>.from(json['request']! as Map<Object?, Object?>),
      ),
      outputFilePath: json['outputFilePath']! as String,
      startedAt: DateTime.parse(json['startedAt']! as String).toUtc(),
    );
  }
}

Future<Process> _startDetachedRecordingProcess(
  String executable,
  List<String> arguments,
) {
  return Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.detachedWithStdio,
  );
}

Future<void> _deleteSimctlSessionFile(File file) async {
  if (!file.existsSync()) {
    return;
  }
  try {
    await file.delete();
  } on Object {
    // Best-effort stale session cleanup.
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
