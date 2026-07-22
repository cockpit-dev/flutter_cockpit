import 'dart:async';
import 'dart:io';

import '../infrastructure/cockpit_process_output_collector.dart';
import '../infrastructure/cockpit_process_manager.dart';

Future<ProcessResult> cockpitRunProcessWithTimeout(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  required Duration timeout,
}) async {
  final process = await cockpitStartIsolatedProcess(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    runInShell: cockpitShouldRunExecutableInShell(executable),
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
    await _killProcessTree(process);
    await process.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () => -1,
    );
    await Future.wait(<Future<void>>[
      stdoutCollector.cancel(),
      stderrCollector.cancel(),
    ]);
    throw TimeoutException(
      '$executable ${arguments.join(' ')} timed out.',
      timeout,
    );
  }
}

bool cockpitShouldRunExecutableInShell(String executable) {
  if (!Platform.isWindows) {
    return false;
  }
  final lower = executable.toLowerCase();
  return lower.endsWith('.bat') || lower.endsWith('.cmd');
}

Future<ProcessResult> cockpitRunShortProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) {
  return cockpitRunProcessWithTimeout(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    timeout: const Duration(seconds: 30),
  );
}

Future<void> _killProcessTree(Process process) async {
  if (Platform.isWindows) {
    try {
      await _runKillHelperProcess('taskkill', <String>[
        '/PID',
        '${process.pid}',
        '/T',
        '/F',
      ]);
      return;
    } on Object {
      // Fall back to direct process termination below.
    }
  }
  if (process.pid > 0) {
    final descendants = await _collectProcessDescendants(process.pid);
    for (final pid in descendants.reversed) {
      try {
        Process.killPid(pid, ProcessSignal.sigkill);
      } on Object {
        // The process may already have exited.
      }
    }
  }
  process.kill(ProcessSignal.sigkill);
}

Future<List<int>> _collectProcessDescendants(int parentPid) async {
  try {
    final result = await _runKillHelperProcess('pgrep', <String>[
      '-P',
      '$parentPid',
    ]);
    if (result.exitCode != 0) {
      return const <int>[];
    }
    final directChildren = '${result.stdout}'
        .split(RegExp(r'\s+'))
        .map((pid) => int.tryParse(pid.trim()))
        .whereType<int>()
        .toList(growable: false);
    final descendants = <int>[];
    for (final childPid in directChildren) {
      descendants.add(childPid);
      descendants.addAll(await _collectProcessDescendants(childPid));
    }
    return descendants;
  } on Object {
    return const <int>[];
  }
}

Future<ProcessResult> _runKillHelperProcess(
  String executable,
  List<String> arguments,
) async {
  final process = await cockpitStartIsolatedProcess(executable, arguments);
  final stdoutCollector = CockpitProcessOutputCollector(process.stdout);
  final stderrCollector = CockpitProcessOutputCollector(process.stderr);
  try {
    final exitCode = await process.exitCode.timeout(const Duration(seconds: 1));
    final output = await Future.wait(<Future<String>>[
      stdoutCollector.collectText(),
      stderrCollector.collectText(),
    ]);
    return ProcessResult(process.pid, exitCode, output[0], output[1]);
  } on Object {
    process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(
      const Duration(milliseconds: 200),
      onTimeout: () => -1,
    );
    return ProcessResult(process.pid, -1, '', '');
  } finally {
    await Future.wait(<Future<void>>[
      stdoutCollector.cancel(),
      stderrCollector.cancel(),
    ]);
  }
}
