import 'package:cockpit_protocol/cockpit_protocol.dart';

import 'cockpit_json_rpc_peer.dart';
import 'cockpit_worker_server.dart';

abstract interface class CockpitWorkerInternalOperationDispatcher {
  Set<String> get internalOperationKinds;

  Future<CockpitOperationResult> executeInternal(
    CockpitOperationInvocation invocation, {
    required String requestId,
    required CockpitRpcCancellation cancellation,
  });
}

final class CockpitWorkerOperationRouter
    implements CockpitWorkerOperationDispatcher {
  CockpitWorkerOperationRouter({
    required CockpitWorkerOperationDispatcher workspaceOperations,
    required Iterable<CockpitWorkerInternalOperationDispatcher>
    internalDispatchers,
  }) : _workspaceOperations = workspaceOperations,
       _internal = <String, CockpitWorkerInternalOperationDispatcher>{} {
    final advertised = workspaceOperations.operationKinds.toSet();
    for (final dispatcher in internalDispatchers) {
      for (final kind in dispatcher.internalOperationKinds) {
        if (advertised.contains(kind) ||
            _internal.putIfAbsent(kind, () => dispatcher) != dispatcher) {
          throw FormatException('Duplicate worker operation route $kind.');
        }
      }
    }
  }

  final CockpitWorkerOperationDispatcher _workspaceOperations;
  final Map<String, CockpitWorkerInternalOperationDispatcher> _internal;

  @override
  List<String> get operationKinds => _workspaceOperations.operationKinds;

  @override
  List<String> get resourceKinds => _workspaceOperations.resourceKinds;

  @override
  Future<CockpitOperationResult> execute(
    CockpitOperationInvocation invocation, {
    required String requestId,
    required CockpitRpcCancellation cancellation,
  }) {
    final internal = _internal[invocation.kind];
    return internal == null
        ? _workspaceOperations.execute(
            invocation,
            requestId: requestId,
            cancellation: cancellation,
          )
        : internal.executeInternal(
            invocation,
            requestId: requestId,
            cancellation: cancellation,
          );
  }
}
