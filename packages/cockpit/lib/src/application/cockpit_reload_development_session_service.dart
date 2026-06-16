import 'dart:io';

import 'package:path/path.dart' as p;

import '../development/cockpit_development_session_handle.dart';
import '../development/cockpit_development_session_reference_resolver.dart';
import '../development/cockpit_development_session_status.dart';
import '../development/cockpit_development_session_supervisor_client.dart';
import 'cockpit_compact_json.dart';

typedef CockpitDevelopmentSessionReloader =
    Future<CockpitDevelopmentSessionReloadResult> Function(
      Uri supervisorBaseUri,
      CockpitDevelopmentReloadMode mode,
    );

final class CockpitReloadDevelopmentSessionRequest {
  const CockpitReloadDevelopmentSessionRequest({
    required this.mode,
    this.sessionHandle,
    this.sessionHandlePath,
  });

  final CockpitDevelopmentReloadMode mode;
  final CockpitDevelopmentSessionHandle? sessionHandle;
  final String? sessionHandlePath;
}

final class CockpitDevelopmentSessionReloadResult {
  const CockpitDevelopmentSessionReloadResult({
    required this.sessionHandle,
    required this.status,
  });

  final CockpitDevelopmentSessionHandle sessionHandle;
  final CockpitDevelopmentSessionStatus status;
}

final class CockpitReloadDevelopmentSessionResult {
  const CockpitReloadDevelopmentSessionResult({
    required this.sessionHandle,
    required this.status,
    this.persistedHandlePath,
  });

  final CockpitDevelopmentSessionHandle sessionHandle;
  final CockpitDevelopmentSessionStatus status;
  final String? persistedHandlePath;
}

final class CockpitReloadDevelopmentSessionService {
  CockpitReloadDevelopmentSessionService({
    CockpitDevelopmentSessionReloader? reloader,
    CockpitDevelopmentSessionReferenceResolver? sessionReferenceResolver,
    CockpitDevelopmentSessionSupervisorClient? supervisorClient,
  }) : _reloader = reloader ?? _buildDefaultReloader(supervisorClient),
       _sessionReferenceResolver =
           sessionReferenceResolver ??
           const CockpitDevelopmentSessionReferenceResolver();

  final CockpitDevelopmentSessionReloader _reloader;
  final CockpitDevelopmentSessionReferenceResolver _sessionReferenceResolver;

  Future<CockpitReloadDevelopmentSessionResult> reload(
    CockpitReloadDevelopmentSessionRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
    );
    final reloaded = await _reloader(resolved.supervisorBaseUri, request.mode);
    final persistedHandlePath = await _persistHandleIfRequested(
      path: request.sessionHandlePath,
      handle: reloaded.sessionHandle,
    );
    return CockpitReloadDevelopmentSessionResult(
      sessionHandle: reloaded.sessionHandle,
      status: reloaded.status,
      persistedHandlePath: persistedHandlePath,
    );
  }

  Future<String?> _persistHandleIfRequested({
    required String? path,
    required CockpitDevelopmentSessionHandle handle,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(cockpitPrettyJsonText(handle.toJson()));
    return p.normalize(file.path);
  }
}

CockpitDevelopmentSessionReloader _buildDefaultReloader(
  CockpitDevelopmentSessionSupervisorClient? supervisorClient,
) {
  final client =
      supervisorClient ?? CockpitDevelopmentSessionSupervisorClient();
  return (supervisorBaseUri, mode) async {
    final response = await client.reload(supervisorBaseUri, mode);
    return CockpitDevelopmentSessionReloadResult(
      sessionHandle: response.sessionHandle,
      status: response.status,
    );
  };
}
