import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../infrastructure/cockpit_process_manager.dart';
import 'cockpit_json_rpc_peer.dart';

final class CockpitWorkerProcessManager implements CockpitProcessManager {
  CockpitWorkerProcessManager({
    CockpitProcessManager? delegate,
    Map<String, String>? environment,
  }) : _delegate = delegate ?? const LocalCockpitProcessManager(),
       _environment = Map<String, String>.unmodifiable(
         cockpitMinimumChildEnvironment(environment: environment),
       );

  final CockpitProcessManager _delegate;
  final Map<String, String> _environment;
  final Object _scopeKey = Object();

  Future<T> runScoped<T>(
    CockpitRpcCancellation cancellation,
    Future<T> Function() action,
  ) {
    final scope = _WorkerProcessScope(
      cancellation: cancellation,
      processManager: _delegate,
    );
    return runZoned<Future<T>>(() async {
      try {
        cancellation.throwIfCancelled();
        return await action();
      } finally {
        scope.close();
      }
    }, zoneValues: <Object, Object>{_scopeKey: scope});
  }

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
  }) async {
    final process = await start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    );
    final stdoutFuture = _collect(process.stdout, stdoutEncoding);
    final stderrFuture = _collect(process.stderr, stderrEncoding);
    final exitCode = await process.exitCode;
    final output = await Future.wait<Object>(<Future<Object>>[
      stdoutFuture,
      stderrFuture,
    ]);
    final scope = Zone.current[_scopeKey] as _WorkerProcessScope?;
    scope?.cancellation.throwIfCancelled();
    return ProcessResult(process.pid, exitCode, output[0], output[1]);
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
  }) async {
    final scope = Zone.current[_scopeKey] as _WorkerProcessScope?;
    scope?.cancellation.throwIfCancelled();
    final process = await _delegate.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: <String, String>{..._environment, ...?environment},
      includeParentEnvironment: false,
      runInShell: runInShell,
      mode: mode,
    );
    scope?.track(process);
    return process;
  }
}

Future<Object> _collect(Stream<List<int>> stream, Encoding? encoding) async {
  if (encoding == null) {
    final bytes = <int>[];
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }
  return stream.transform(encoding.decoder).join();
}

final class _WorkerProcessScope {
  _WorkerProcessScope({
    required this.cancellation,
    required CockpitProcessManager processManager,
  }) : _processManager = processManager {
    unawaited(cancellation.whenCancelled.then((_) => _cancel()));
  }

  final CockpitRpcCancellation cancellation;
  final CockpitProcessManager _processManager;
  final Set<Process> _processes = <Process>{};
  var _closed = false;

  void track(Process process) {
    if (_closed || cancellation.isCancelled) {
      unawaited(_terminate(process));
      return;
    }
    _processes.add(process);
    process.exitCode.whenComplete(() => _processes.remove(process));
  }

  void close() {
    _closed = true;
    _processes.clear();
  }

  Future<void> _cancel() async {
    if (_closed) return;
    final processes = _processes.toList(growable: false);
    await Future.wait<void>(processes.map(_terminate));
  }

  Future<void> _terminate(Process process) async {
    if (process.pid > 1) {
      final processManager = _processManager;
      if (processManager is LocalCockpitProcessManager &&
          processManager.usesHostProcessManager) {
        await cockpitKillLocalProcessDescendants(process.pid);
      }
    }
    process.kill(ProcessSignal.sigkill);
    await process.exitCode.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => -1,
    );
  }
}
