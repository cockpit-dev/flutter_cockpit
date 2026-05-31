import 'dart:io';

import '../development/cockpit_development_session_handle.dart';
import '../development/cockpit_development_session_reference_resolver.dart';
import '../development/cockpit_development_session_status.dart';
import '../development/cockpit_development_session_supervisor_client.dart';

typedef CockpitDevelopmentSessionStopper =
    Future<CockpitDevelopmentSessionStopResult> Function(Uri supervisorBaseUri);

final class CockpitStopDevelopmentSessionRequest {
  const CockpitStopDevelopmentSessionRequest({
    this.sessionHandle,
    this.sessionHandlePath,
  });

  final CockpitDevelopmentSessionHandle? sessionHandle;
  final String? sessionHandlePath;
}

final class CockpitDevelopmentSessionStopResult {
  const CockpitDevelopmentSessionStopResult({
    required this.sessionHandle,
    required this.status,
  });

  final CockpitDevelopmentSessionHandle sessionHandle;
  final CockpitDevelopmentSessionStatus status;
}

final class CockpitStopDevelopmentSessionResult {
  const CockpitStopDevelopmentSessionResult({
    required this.sessionHandle,
    required this.status,
  });

  final CockpitDevelopmentSessionHandle sessionHandle;
  final CockpitDevelopmentSessionStatus status;
}

final class CockpitStopDevelopmentSessionService {
  CockpitStopDevelopmentSessionService({
    CockpitDevelopmentSessionStopper? stopper,
    CockpitDevelopmentSessionReferenceResolver? sessionReferenceResolver,
    CockpitDevelopmentSessionSupervisorClient? supervisorClient,
  }) : _stopper = stopper ?? _buildDefaultStopper(supervisorClient),
       _sessionReferenceResolver =
           sessionReferenceResolver ??
           const CockpitDevelopmentSessionReferenceResolver();

  final CockpitDevelopmentSessionStopper _stopper;
  final CockpitDevelopmentSessionReferenceResolver _sessionReferenceResolver;

  Future<CockpitStopDevelopmentSessionResult> stop(
    CockpitStopDevelopmentSessionRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
    );
    late final CockpitDevelopmentSessionStopResult stopped;
    try {
      stopped = await _stopper(resolved.supervisorBaseUri);
    } on SocketException catch (error) {
      final handle = resolved.sessionHandle;
      if (handle == null) {
        rethrow;
      }
      stopped = CockpitDevelopmentSessionStopResult(
        sessionHandle: handle,
        status: CockpitDevelopmentSessionStatus(
          developmentSessionId: handle.developmentSessionId,
          state: CockpitDevelopmentSessionState.stopped,
          appReachable: false,
          remoteSessionReachable: false,
          reloadGeneration: handle.reloadGeneration,
          lastError: error.toString(),
          lastStatusAt: DateTime.now().toUtc(),
        ),
      );
    }
    return CockpitStopDevelopmentSessionResult(
      sessionHandle: stopped.sessionHandle,
      status: stopped.status,
    );
  }
}

CockpitDevelopmentSessionStopper _buildDefaultStopper(
  CockpitDevelopmentSessionSupervisorClient? supervisorClient,
) {
  final client =
      supervisorClient ?? CockpitDevelopmentSessionSupervisorClient();
  return (supervisorBaseUri) async {
    final response = await client.stop(supervisorBaseUri);
    return CockpitDevelopmentSessionStopResult(
      sessionHandle: response.sessionHandle,
      status: response.status,
    );
  };
}
