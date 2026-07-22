import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../infrastructure/cockpit_process_manager.dart';
import '../foundation/cockpit_ids.dart';
import '../worker/cockpit_json_rpc_peer.dart';
import '../worker/cockpit_worker_logger.dart';
import '../worker/cockpit_worker_server.dart';
import 'cockpit_supervisor_worker_endpoint.dart';
import 'cockpit_supervisor_port_ownership_inspector.dart';
import 'cockpit_supervisor_worker_port_bridge.dart';
import 'cockpit_worker_pool.dart';
import 'cockpit_worker_resource_authority.dart';

typedef CockpitSupervisorEventExchangeFactory =
    CockpitWorkerEventExchange Function(CockpitWorkspaceWorkerSpec spec);
typedef CockpitSupervisorResourceAuthorityFactory =
    CockpitSupervisorWorkerResourceAuthority Function(
      CockpitWorkspaceWorkerSpec spec,
      CockpitSupervisorWorkerPortBridge portBridge,
    );

final class CockpitLocalWorkerLauncher
    implements CockpitWorkspaceWorkerLauncher {
  CockpitLocalWorkerLauncher({
    required this.dartExecutable,
    required this.workerEntrypoint,
    required CockpitSupervisorEventExchangeFactory eventExchangeFactory,
    required CockpitSupervisorResourceAuthorityFactory resourceAuthorityFactory,
    CockpitProcessManager processManager = const LocalCockpitProcessManager(),
    CockpitWorkerLogger? logger,
    CockpitTokenGenerator? tokenGenerator,
    Map<String, String>? environment,
    Iterable<String> allowedEnvironmentSecretNames = const <String>[],
  }) : _eventExchangeFactory = eventExchangeFactory,
       _resourceAuthorityFactory = resourceAuthorityFactory,
       _processManager = processManager,
       _logger = logger ?? CockpitWorkerLogger(),
       _tokenGenerator = tokenGenerator ?? CockpitSecureTokenGenerator(),
       _environment = Map<String, String>.unmodifiable(
         environment ?? _minimumWorkerEnvironment(),
       ),
       _allowedEnvironmentSecretNames = List<String>.unmodifiable(
         allowedEnvironmentSecretNames,
       ) {
    if (dartExecutable.isEmpty || workerEntrypoint.isEmpty) {
      throw ArgumentError('Worker executable paths cannot be empty.');
    }
    final uniqueSecretNames = <String>{};
    for (final name in _allowedEnvironmentSecretNames) {
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,127}$').hasMatch(name) ||
          !uniqueSecretNames.add(name) ||
          !_environment.containsKey(name)) {
        throw ArgumentError(
          'Allowed worker environment secrets must be unique and present.',
        );
      }
    }
  }

  final String dartExecutable;
  final String workerEntrypoint;
  final CockpitSupervisorEventExchangeFactory _eventExchangeFactory;
  final CockpitSupervisorResourceAuthorityFactory _resourceAuthorityFactory;
  final CockpitProcessManager _processManager;
  final CockpitWorkerLogger _logger;
  final CockpitTokenGenerator _tokenGenerator;
  final Map<String, String> _environment;
  final List<String> _allowedEnvironmentSecretNames;

  @override
  Future<CockpitWorkspaceWorkerConnection> launch(
    CockpitWorkspaceWorkerSpec spec,
  ) async {
    final workerOwnerId = 'worker_${_tokenGenerator.nextToken(byteLength: 16)}';
    final processStartIdentity =
        'process_${_tokenGenerator.nextToken(byteLength: 16)}';
    final workerTemporaryRoot = p.join(
      spec.stateRoot,
      'producer_artifacts',
      'tmp',
    );
    final process = await _processManager.start(
      dartExecutable,
      <String>[
        workerEntrypoint,
        '--workspace-id=${spec.key.workspaceId}',
        '--project-id=${spec.projectId}',
        '--engine-version=${spec.key.engineVersion}',
        '--workspace-root=${spec.workspaceRoot}',
        '--state-root=${spec.stateRoot}',
        '--worker-owner-id=$workerOwnerId',
        '--process-start-identity=$processStartIdentity',
        for (final feature in spec.supportedFeatures) '--feature=$feature',
        for (final name in _allowedEnvironmentSecretNames)
          '--allow-env-secret=$name',
        for (final environment in spec.allowedTargetEnvironments)
          '--allow-target-environment=${environment.name}',
        for (final effect in spec.allowedSafetyEffects)
          '--allow-safety-effect=${effect.name}',
      ],
      workingDirectory: spec.workspaceRoot,
      environment: <String, String>{
        ..._environment,
        'TMPDIR': workerTemporaryRoot,
        'TMP': workerTemporaryRoot,
        'TEMP': workerTemporaryRoot,
      },
      includeParentEnvironment: false,
    );
    late final CockpitSystemSupervisorPortOwnershipInspector ownershipInspector;
    try {
      ownershipInspector =
          await CockpitSystemSupervisorPortOwnershipInspector.capture(
            workerProcessId: process.pid,
          );
    } on Object {
      process.kill(ProcessSignal.sigkill);
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () => -1,
      );
      rethrow;
    }
    late final CockpitJsonRpcPeer peer;
    final portBridge = CockpitSupervisorWorkerPortBridge(
      workspaceId: spec.key.workspaceId,
      workerOwnerId: workerOwnerId,
      workerProcessId: process.pid,
      processStartIdentity: processStartIdentity,
      ownershipInspector: ownershipInspector,
      call: ({required method, required params, required deadline}) =>
          peer.call(method: method, params: params, deadline: deadline),
    );
    final endpoint = CockpitSupervisorWorkerEndpoint(
      workspaceId: spec.key.workspaceId,
      events: _eventExchangeFactory(spec),
      resourceAuthority: _resourceAuthorityFactory(spec, portBridge),
    );
    peer = CockpitJsonRpcPeer(
      input: process.stdout,
      output: process.stdin,
      requestHandler: endpoint.handle,
      onProtocolError: (error, _) {
        _logger.log(
          'error',
          'Worker protocol error.',
          fields: <String, Object?>{
            'workspaceId': spec.key.workspaceId,
            'error': '$error',
          },
        );
      },
    );
    peer.start();
    final stderrSubscription = process.stderr
        .transform(const CockpitBoundedUtf8LineFramer())
        .listen((line) {
          _logger.log(
            'info',
            'Workspace worker stderr.',
            fields: <String, Object?>{
              'workspaceId': spec.key.workspaceId,
              'processId': process.pid,
              'line': line.text,
              'truncated': line.truncated,
            },
          );
        });
    return _LocalWorkerConnection(
      process: process,
      processManager: _processManager,
      peer: peer,
      stderrSubscription: stderrSubscription,
    );
  }
}

final class _LocalWorkerConnection implements CockpitWorkspaceWorkerConnection {
  _LocalWorkerConnection({
    required Process process,
    required CockpitProcessManager processManager,
    required CockpitJsonRpcPeer peer,
    required StreamSubscription<CockpitBoundedLogLine> stderrSubscription,
  }) : _process = process,
       _processManager = processManager,
       _peer = peer,
       _stderrSubscription = stderrSubscription;

  final Process _process;
  final CockpitProcessManager _processManager;
  final CockpitJsonRpcPeer _peer;
  final StreamSubscription<CockpitBoundedLogLine> _stderrSubscription;
  var _terminated = false;
  Future<void>? _termination;

  @override
  int get processId => _process.pid;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool get isClosed => _terminated || _peer.isClosed;

  @override
  Future<Object?> call({
    required String method,
    required Map<String, Object?> params,
    required DateTime deadline,
    String? requestId,
  }) => _peer.call(
    method: method,
    params: params,
    deadline: deadline,
    requestId: requestId,
  );

  @override
  Future<void> terminate({required bool force}) async {
    if (_terminated) return;
    final active = _termination;
    if (active != null) return active;
    late final Future<void> operation;
    operation = _terminate(force: force).whenComplete(() {
      if (identical(_termination, operation)) _termination = null;
    });
    _termination = operation;
    return operation;
  }

  Future<void> _terminate({required bool force}) async {
    if (!force) {
      await _peer.close();
      if (await _waitForExit()) {
        await _stderrSubscription.cancel();
        _terminated = true;
        return;
      }
    }
    final processManager = _processManager;
    if (_process.pid > 1 &&
        processManager is LocalCockpitProcessManager &&
        processManager.usesHostProcessManager) {
      await cockpitKillLocalProcessDescendants(_process.pid);
    }
    _process.kill(ProcessSignal.sigkill);
    if (!await _waitForExit()) {
      throw const CockpitWorkerPoolException(
        'workerTerminationFailed',
        'Worker process did not exit after a forced termination request.',
      );
    }
    await _peer.close(closeOutput: false);
    await _stderrSubscription.cancel();
    _terminated = true;
  }

  Future<bool> _waitForExit() => _process.exitCode
      .then((_) => true)
      .timeout(const Duration(seconds: 2), onTimeout: () => false);
}

Map<String, String> _minimumWorkerEnvironment() {
  const allowed = <String>{
    'PATH',
    'HOME',
    'USERPROFILE',
    'TMPDIR',
    'TMP',
    'TEMP',
    'SystemRoot',
    'WINDIR',
    'LANG',
    'LC_ALL',
  };
  return <String, String>{
    for (final entry in Platform.environment.entries)
      if (allowed.contains(entry.key)) entry.key: entry.value,
  };
}
