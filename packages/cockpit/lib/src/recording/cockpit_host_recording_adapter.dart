import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import '../adapters/cockpit_recording_adapter.dart';
import '../session/cockpit_session_process_runner.dart';

typedef CockpitRecordingProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);
typedef CockpitRecordingProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);
typedef CockpitRecordingTimedProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      required Duration timeout,
    });
typedef CockpitRecordingTempFileFactory =
    Future<File> Function(String basename);
typedef CockpitPidSignalSender = bool Function(int pid, ProcessSignal signal);
typedef CockpitPidLivenessChecker = Future<bool> Function(int pid);

const Duration cockpitDefaultRecordingCommandTimeout = Duration(seconds: 5);

abstract interface class CockpitHostRecordingAdapter
    implements CockpitRecordingAdapter {}

Future<ProcessResult> cockpitRunRecordingProcessWithTimeout(
  String executable,
  List<String> arguments, {
  required Duration timeout,
}) {
  return cockpitRunProcessWithTimeout(executable, arguments, timeout: timeout);
}

final class CockpitHostRecordingRuntimeSession {
  const CockpitHostRecordingRuntimeSession({
    required this.process,
    required this.request,
    required this.outputFile,
    required this.stderrSubscription,
    required this.stopwatch,
    this.startedAt,
    this.remotePath,
    this.recentStderrLines = const <String>[],
  });

  final Process process;
  final CockpitRecordingRequest request;
  final File outputFile;
  final StreamSubscription<String>? stderrSubscription;
  final Stopwatch? stopwatch;
  final DateTime? startedAt;
  final String? remotePath;
  final List<String> recentStderrLines;
}

final class CockpitHostRecordingPersistedSession {
  const CockpitHostRecordingPersistedSession({
    required this.pid,
    required this.request,
    required this.outputFilePath,
    required this.startedAt,
    this.remotePath,
    this.stderrLogPath,
    this.kind = CockpitRecordingKind.nativeScreen,
  });

  final int pid;
  final CockpitRecordingRequest request;
  final String outputFilePath;
  final DateTime startedAt;
  final String? remotePath;
  final String? stderrLogPath;
  final CockpitRecordingKind kind;

  Map<String, Object?> toJson() => <String, Object?>{
    'pid': pid,
    'request': request.toJson(),
    'outputFilePath': outputFilePath,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (remotePath != null) 'remotePath': remotePath,
    if (stderrLogPath != null) 'stderrLogPath': stderrLogPath,
    'kind': kind.name,
  };

  factory CockpitHostRecordingPersistedSession.fromJson(
    Map<String, Object?> json,
  ) {
    final requestJson = json['request'];
    if (requestJson is! Map<Object?, Object?>) {
      throw const FormatException('Missing recording request.');
    }
    return CockpitHostRecordingPersistedSession(
      pid: json['pid']! as int,
      request: CockpitRecordingRequest.fromJson(
        Map<String, Object?>.from(requestJson),
      ),
      outputFilePath: json['outputFilePath']! as String,
      startedAt: DateTime.parse(json['startedAt']! as String).toUtc(),
      remotePath: json['remotePath'] as String?,
      stderrLogPath: json['stderrLogPath'] as String?,
      kind: json['kind'] == null
          ? CockpitRecordingKind.nativeScreen
          : CockpitRecordingKind.values.firstWhere(
              (candidate) => candidate.name == json['kind'],
              orElse: () => CockpitRecordingKind.nativeScreen,
            ),
    );
  }
}

final class CockpitHostRecordingSessionPaths {
  const CockpitHostRecordingSessionPaths({
    required this.sessionFile,
    required this.stderrLogFile,
  });

  final File sessionFile;
  final File stderrLogFile;
}

final Map<String, CockpitHostRecordingRuntimeSession>
_activeHostRecordingSessions = <String, CockpitHostRecordingRuntimeSession>{};

CockpitHostRecordingRuntimeSession? cockpitReadActiveHostRecordingSession(
  String key,
) {
  return _activeHostRecordingSessions[key];
}

bool cockpitHasActiveHostRecordingSession(String key) {
  return _activeHostRecordingSessions.containsKey(key) ||
      cockpitReadPersistedHostRecordingSession(key) != null;
}

Future<bool> cockpitHasLiveHostRecordingSession(
  String key, {
  CockpitPidLivenessChecker pidLivenessChecker =
      cockpitDefaultPidLivenessChecker,
}) async {
  if (_activeHostRecordingSessions.containsKey(key)) {
    return true;
  }
  final persisted = cockpitReadPersistedHostRecordingSession(key);
  if (persisted == null) {
    return false;
  }
  if (await pidLivenessChecker(persisted.pid)) {
    return true;
  }
  cockpitClearPersistedHostRecordingSession(key);
  return false;
}

void cockpitStoreActiveHostRecordingSession(
  String key,
  CockpitHostRecordingRuntimeSession session,
) {
  _activeHostRecordingSessions[key] = session;
}

void cockpitClearActiveHostRecordingSession(String key) {
  _activeHostRecordingSessions.remove(key);
  cockpitClearPersistedHostRecordingSession(key);
}

CockpitHostRecordingPersistedSession? cockpitReadPersistedHostRecordingSession(
  String key,
) {
  final file = cockpitHostRecordingSessionPaths(key).sessionFile;
  if (!file.existsSync()) {
    return null;
  }
  try {
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<Object?, Object?>) {
      file.deleteSync();
      return null;
    }
    return CockpitHostRecordingPersistedSession.fromJson(
      Map<String, Object?>.from(decoded),
    );
  } on Object {
    try {
      file.deleteSync();
    } on Object {
      // Best-effort cleanup for malformed persisted session metadata.
    }
    return null;
  }
}

Future<void> cockpitPersistHostRecordingSession(
  String key,
  CockpitHostRecordingPersistedSession session,
) async {
  final file = cockpitHostRecordingSessionPaths(key).sessionFile;
  await file.parent.create(recursive: true);
  await file.writeAsString(jsonEncode(session.toJson()), flush: true);
}

void cockpitClearPersistedHostRecordingSession(String key) {
  final file = cockpitHostRecordingSessionPaths(key).sessionFile;
  if (!file.existsSync()) {
    return;
  }
  try {
    file.deleteSync();
  } on Object {
    // Best-effort cleanup; stale sessions are revalidated on the next start.
  }
}

CockpitHostRecordingSessionPaths cockpitHostRecordingSessionPaths(String key) {
  final sanitizedKey = key.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final directory = Directory(
    p.join(Directory.systemTemp.path, 'flutter_cockpit_recording_sessions'),
  );
  return CockpitHostRecordingSessionPaths(
    sessionFile: File(p.join(directory.path, '$sanitizedKey.json')),
    stderrLogFile: File(p.join(directory.path, '$sanitizedKey.stderr.log')),
  );
}

Future<File> cockpitCreateRecordingTempFile(String basename) async {
  final directory = await Directory.systemTemp.createTemp(
    'flutter_cockpit_recording_',
  );
  return File(p.join(directory.path, basename));
}

Future<Process> cockpitStartDetachedRecordingProcess(
  String executable,
  List<String> arguments,
) {
  return Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.detachedWithStdio,
  );
}

CockpitArtifactRef cockpitRecordingArtifactForName(String recordingName) {
  return CockpitArtifactRef(
    role: 'recording',
    relativePath: 'recordings/${cockpitRecordingFileName(recordingName)}',
  );
}

String cockpitRecordingFileName(String recordingName) {
  final sanitized = recordingName.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final basename = sanitized.isEmpty ? 'recording' : sanitized;
  return '$basename.mp4';
}

Future<bool> cockpitWaitForNonEmptyFile(
  File file, {
  required Duration timeout,
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (file.existsSync() && file.lengthSync() > 0) {
      return true;
    }
    await Future<void>.delayed(pollInterval);
  }
  return file.existsSync() && file.lengthSync() > 0;
}

Future<bool> cockpitWaitForStableFile(
  File file, {
  required Duration timeout,
  Duration pollInterval = const Duration(milliseconds: 100),
  Duration stableWindow = const Duration(milliseconds: 400),
}) async {
  final deadline = DateTime.now().add(timeout);
  int? lastLength;
  DateTime? stableSince;

  while (DateTime.now().isBefore(deadline)) {
    if (file.existsSync() && file.lengthSync() > 0) {
      final currentLength = file.lengthSync();
      if (lastLength == currentLength) {
        stableSince ??= DateTime.now();
        if (DateTime.now().difference(stableSince) >= stableWindow) {
          return true;
        }
      } else {
        lastLength = currentLength;
        stableSince = DateTime.now();
      }
    }
    await Future<void>.delayed(pollInterval);
  }

  if (!file.existsSync() || file.lengthSync() <= 0) {
    return false;
  }
  return lastLength == file.lengthSync();
}

Future<bool> cockpitWaitForRecordingProcessExit(
  Process process, {
  required Duration timeout,
}) async {
  try {
    await process.exitCode.timeout(timeout);
    return true;
  } on Object {
    return false;
  }
}

Future<bool> cockpitWaitForRecordingProcessOrPidExit(
  Process process, {
  required Duration timeout,
  required CockpitPidLivenessChecker livenessChecker,
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  try {
    await process.exitCode.timeout(timeout);
    return true;
  } on TimeoutException {
    return cockpitWaitForPidExit(
      process.pid,
      timeout: Duration.zero,
      livenessChecker: livenessChecker,
      pollInterval: pollInterval,
    );
  } on Object {
    return cockpitWaitForPidExit(
      process.pid,
      timeout: timeout,
      livenessChecker: livenessChecker,
      pollInterval: pollInterval,
    );
  }
}

Future<bool> cockpitKillRecordingProcess(
  Process process, {
  ProcessSignal signal = ProcessSignal.sigkill,
  Duration waitTimeout = const Duration(seconds: 2),
  CockpitPidLivenessChecker livenessChecker = cockpitDefaultPidLivenessChecker,
}) async {
  try {
    process.kill(signal);
  } on Object {
    // The process may already have exited or the platform may reject a signal.
  }
  return cockpitWaitForRecordingProcessOrPidExit(
    process,
    timeout: waitTimeout,
    livenessChecker: livenessChecker,
  );
}

Future<bool> cockpitWaitForPidExit(
  int pid, {
  required Duration timeout,
  required CockpitPidLivenessChecker livenessChecker,
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (!await livenessChecker(pid)) {
      return true;
    }
    await Future<void>.delayed(pollInterval);
  }
  return !await livenessChecker(pid);
}

Future<bool> cockpitSignalRecordingPid(
  int pid,
  ProcessSignal signal, {
  required CockpitPidSignalSender signalSender,
  required CockpitPidLivenessChecker livenessChecker,
  required Duration waitTimeout,
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  try {
    signalSender(pid, signal);
  } on Object {
    return !await livenessChecker(pid);
  }
  return cockpitWaitForPidExit(
    pid,
    timeout: waitTimeout,
    livenessChecker: livenessChecker,
    pollInterval: pollInterval,
  );
}

Future<bool> cockpitDefaultPidLivenessChecker(
  int pid, {
  CockpitRecordingTimedProcessRunner runProcess =
      cockpitRunRecordingProcessWithTimeout,
}) async {
  if (pid <= 0) {
    return false;
  }
  if (Platform.isWindows) {
    try {
      final result = await runProcess('tasklist', <String>[
        '/FI',
        'PID eq $pid',
        '/FO',
        'CSV',
        '/NH',
      ], timeout: const Duration(seconds: 2));
      if (result.exitCode != 0) {
        return false;
      }
      return '${result.stdout}'.contains('"$pid"') ||
          '${result.stdout}'.contains(',$pid,') ||
          '${result.stdout}'.contains(' $pid ');
    } on TimeoutException {
      return true;
    } on Object {
      return false;
    }
  }
  ProcessResult signalResult;
  try {
    signalResult = await runProcess('/bin/kill', <String>[
      '-0',
      '$pid',
    ], timeout: const Duration(seconds: 2));
  } on TimeoutException {
    return true;
  } on Object {
    return false;
  }
  if (signalResult.exitCode != 0) {
    return false;
  }

  try {
    final statResult = await runProcess('/bin/ps', <String>[
      '-o',
      'stat=',
      '-p',
      '$pid',
    ], timeout: const Duration(seconds: 2));
    if (statResult.exitCode != 0) {
      return true;
    }

    final state = '${statResult.stdout}'.trimLeft();
    if (state.isEmpty) {
      return false;
    }
    return !state.startsWith('Z');
  } on TimeoutException {
    return true;
  } on Object {
    return true;
  }
}

List<String> cockpitRecentHostRecordingStderrLines(
  CockpitHostRecordingPersistedSession session, {
  int maxLines = 8,
}) {
  final stderrLogPath = session.stderrLogPath;
  if (stderrLogPath == null || stderrLogPath.isEmpty) {
    return const <String>[];
  }
  final file = File(stderrLogPath);
  if (!file.existsSync()) {
    return const <String>[];
  }
  try {
    final lines = file
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.length <= maxLines) {
      return lines;
    }
    return lines.sublist(lines.length - maxLines);
  } on Object {
    return const <String>[];
  }
}

Future<void> cockpitReleaseRecordingProcessStreams({
  required StreamSubscription<List<int>>? stdoutSubscription,
  required StreamSubscription<String>? stderrSubscription,
}) async {
  await cockpitCancelRecordingSubscription(stdoutSubscription);
  await cockpitCancelRecordingSubscription(stderrSubscription);
}

Future<void> cockpitCancelRecordingSubscription<T>(
  StreamSubscription<T>? subscription,
) async {
  if (subscription == null) {
    return;
  }
  try {
    await subscription.cancel().timeout(const Duration(milliseconds: 500));
  } on Object {
    // Releasing parent-side diagnostics must not break a started recording.
  }
}
