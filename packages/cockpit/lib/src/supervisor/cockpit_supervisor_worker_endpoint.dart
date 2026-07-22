import '../worker/cockpit_json_rpc_message.dart';
import '../worker/cockpit_json_rpc_peer.dart';
import '../worker/cockpit_worker_protocol_request.dart';
import '../worker/cockpit_worker_protocol_result.dart';
import '../worker/cockpit_worker_protocol_schema.dart';
import '../worker/cockpit_worker_value_reader.dart';
import '../worker/cockpit_worker_server.dart';
import 'cockpit_worker_resource_authority.dart';

final class CockpitSupervisorWorkerEndpoint {
  CockpitSupervisorWorkerEndpoint({
    required this.workspaceId,
    required CockpitWorkerEventExchange events,
    required CockpitSupervisorWorkerResourceAuthority resourceAuthority,
  }) : _events = events,
       _resourceAuthority = resourceAuthority {
    workerId(workspaceId, r'$.workspaceId');
  }

  final String workspaceId;
  final CockpitWorkerEventExchange _events;
  final CockpitSupervisorWorkerResourceAuthority _resourceAuthority;

  Future<Object?> handle(
    CockpitJsonRpcRequest request,
    CockpitRpcCancellation cancellation,
  ) async {
    if (request.params['protocolVersion'] != cockpitWorkerProtocolVersion) {
      throw _endpointError(
        'upgradeRequired',
        'Worker protocol version is incompatible.',
      );
    }
    if (request.params['workspaceId'] != workspaceId) {
      throw _endpointError(
        'workspaceMismatch',
        'Worker request belongs to another workspace.',
      );
    }
    CockpitWorkerProtocolSchema.validateRequest(request.method, request.params);
    final decoded = CockpitWorkerProtocolRequest.fromJson(
      request.method,
      request.params,
    );
    if (decoded.requestId != request.id) {
      throw _endpointError(
        'requestIdMismatch',
        'Worker request id does not match its JSON-RPC envelope.',
      );
    }
    cancellation.throwIfCancelled();
    final result = switch (decoded) {
      CockpitWorkerPublishEventBatchRequest() => (await _events.publish(
        decoded,
      )).toJson(),
      CockpitWorkerOperationRequest() => CockpitWorkerOperationResult(
        await _resourceAuthority.execute(decoded.invocation),
      ).toJson(),
      _ => throw _endpointError(
        'methodUnavailable',
        'Method ${decoded.method} is not accepted by the Supervisor peer.',
      ),
    };
    CockpitWorkerProtocolSchema.validateResult(decoded.method, result);
    return result;
  }
}

CockpitJsonRpcRemoteException _endpointError(String code, String message) =>
    CockpitJsonRpcRemoteException(
      CockpitJsonRpcError(code: -32000, message: message, workerCode: code),
    );
