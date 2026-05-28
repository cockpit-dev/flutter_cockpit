import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<ProcessResult> cockpitRunProcessWithTimeout(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  required Duration timeout,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  final stdoutFuture = process.stdout.fold<List<int>>(
    <int>[],
    (buffer, chunk) => buffer..addAll(chunk),
  );
  final stderrFuture = process.stderr.fold<List<int>>(
    <int>[],
    (buffer, chunk) => buffer..addAll(chunk),
  );

  try {
    final exitCode = await process.exitCode.timeout(timeout);
    return ProcessResult(
      process.pid,
      exitCode,
      _decodeProcessOutput(await stdoutFuture),
      _decodeProcessOutput(await stderrFuture),
    );
  } on TimeoutException {
    await _killProcessTree(process);
    await process.exitCode.timeout(
      const Duration(seconds: 2),
      onTimeout: () => -1,
    );
    throw TimeoutException(
      '$executable ${arguments.join(' ')} timed out.',
      timeout,
    );
  }
}

Future<ProcessResult> cockpitRunShortProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return cockpitRunProcessWithTimeout(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    timeout: const Duration(seconds: 30),
  );
}

String _decodeProcessOutput(List<int> bytes) {
  try {
    return systemEncoding.decode(bytes);
  } on FormatException {
    return utf8.decode(bytes, allowMalformed: true);
  }
}

Future<void> _killProcessTree(Process process) async {
  if (Platform.isWindows) {
    try {
      await Process.run('taskkill', <String>[
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
    final result = await Process.run('pgrep', <String>['-P', '$parentPid']);
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
