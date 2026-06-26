import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';

import 'cockpit_process_output_collector.dart';

abstract interface class CockpitProcessManager {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  });

  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  });
}

final class CockpitManagedProcessTimeoutException implements TimeoutException {
  const CockpitManagedProcessTimeoutException({
    required this.executable,
    required this.arguments,
    required this.stdout,
    required this.stderr,
    required Duration timeout,
  }) : duration = timeout,
       message = 'Managed process timed out.';

  final String executable;
  final List<String> arguments;
  final String stdout;
  final String stderr;

  @override
  final String message;

  @override
  final Duration duration;

  @override
  String toString() =>
      'TimeoutException after ${duration.inMilliseconds}ms: '
      '$executable ${arguments.join(' ')}';
}

final class LocalCockpitProcessManager implements CockpitProcessManager {
  const LocalCockpitProcessManager({
    ProcessManager processManager = const LocalProcessManager(),
  }) : _processManager = processManager;

  final ProcessManager _processManager;

  bool get usesHostProcessManager => _processManager is LocalProcessManager;

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    return _processManager.run(
      <Object>[executable, ...arguments],
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return _processManager.start(
      <Object>[executable, ...arguments],
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );
  }
}

Future<ProcessResult> cockpitRunManagedProcessWithTimeout(
  CockpitProcessManager processManager,
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final process = await processManager.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  final stdoutCollector = CockpitProcessOutputCollector(process.stdout);
  final stderrCollector = CockpitProcessOutputCollector(process.stderr);
  try {
    final exitCode = await process.exitCode.timeout(timeout);
    final output = await Future.wait(<Future<String>>[
      stdoutCollector.collectText(),
      stderrCollector.collectText(),
    ]);
    return ProcessResult(process.pid, exitCode, output[0], output[1]);
  } on TimeoutException {
    if (process.pid != 0) {
      if (processManager case final LocalCockpitProcessManager manager
          when manager.usesHostProcessManager) {
        await cockpitKillLocalProcessDescendants(process.pid);
      }
      process.kill(ProcessSignal.sigkill);
    }
    await process.exitCode.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => -1,
    );
    final output = await Future.wait(<Future<String>>[
      stdoutCollector.collectText(),
      stderrCollector.collectText(),
    ]);
    throw CockpitManagedProcessTimeoutException(
      executable: executable,
      arguments: List<String>.unmodifiable(arguments),
      stdout: output[0],
      stderr: output[1],
      timeout: timeout,
    );
  } finally {
    await Future.wait(<Future<void>>[
      stdoutCollector.cancel(),
      stderrCollector.cancel(),
    ]);
  }
}

Future<void> cockpitKillLocalProcessDescendants(int rootPid) async {
  if (rootPid <= 1) return;
  try {
    if (Platform.isWindows) {
      await Process.run(
        'taskkill',
        <String>['/PID', '$rootPid', '/T', '/F'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(milliseconds: 800));
      return;
    }

    final result = await Process.run(
      'ps',
      const <String>['-axo', 'pid=,ppid='],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    ).timeout(const Duration(milliseconds: 800));
    final descendants = cockpitProcessDescendantsFromPs(
      '${result.stdout}',
      rootPid,
    );
    for (final pid in descendants.toList().reversed) {
      if (pid > 0 && pid != rootPid) {
        Process.killPid(pid, ProcessSignal.sigkill);
      }
    }
  } on Object {
    // Timeout cleanup is best-effort. The direct process is still killed by the
    // caller, and the original timeout remains the reported failure.
  }
}

List<int> cockpitProcessDescendantsFromPs(String psOutput, int rootPid) {
  final childrenByParent = <int, List<int>>{};
  for (final line in const LineSplitter().convert(psOutput)) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    final pid = int.tryParse(parts[0]);
    final parentPid = int.tryParse(parts[1]);
    if (pid == null || parentPid == null || pid == rootPid) continue;
    childrenByParent.putIfAbsent(parentPid, () => <int>[]).add(pid);
  }

  final descendants = <int>[];
  final pending = <int>[rootPid];
  final seen = <int>{rootPid};
  while (pending.isNotEmpty) {
    final parent = pending.removeLast();
    for (final child in childrenByParent[parent] ?? const <int>[]) {
      if (!seen.add(child)) continue;
      descendants.add(child);
      pending.add(child);
    }
  }
  return descendants;
}
