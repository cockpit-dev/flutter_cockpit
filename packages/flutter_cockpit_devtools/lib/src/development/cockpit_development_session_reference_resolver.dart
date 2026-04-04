import 'dart:convert';
import 'dart:io';

import '../application/cockpit_application_service_exception.dart';
import '../application/cockpit_json_key_normalizer.dart';
import 'cockpit_development_session_handle.dart';

final class CockpitResolvedDevelopmentSessionReference {
  const CockpitResolvedDevelopmentSessionReference({
    required this.supervisorBaseUri,
    required this.remoteBaseUri,
    this.sessionHandle,
  });

  final Uri supervisorBaseUri;
  final Uri remoteBaseUri;
  final CockpitDevelopmentSessionHandle? sessionHandle;
}

final class CockpitDevelopmentSessionReferenceResolver {
  const CockpitDevelopmentSessionReferenceResolver();

  Future<CockpitResolvedDevelopmentSessionReference> resolve({
    CockpitDevelopmentSessionHandle? sessionHandle,
    String? sessionHandlePath,
  }) async {
    if (sessionHandle != null) {
      return CockpitResolvedDevelopmentSessionReference(
        supervisorBaseUri: sessionHandle.supervisorBaseUri,
        remoteBaseUri: sessionHandle.baseUri,
        sessionHandle: sessionHandle,
      );
    }

    if (sessionHandlePath != null && sessionHandlePath.isNotEmpty) {
      final resolvedHandle = await readSessionHandle(sessionHandlePath);
      return CockpitResolvedDevelopmentSessionReference(
        supervisorBaseUri: resolvedHandle.supervisorBaseUri,
        remoteBaseUri: resolvedHandle.baseUri,
        sessionHandle: resolvedHandle,
      );
    }

    throw const CockpitApplicationServiceException(
      code: 'missingDevelopmentSessionReference',
      message:
          'A development session handle or persisted handle path is required.',
    );
  }

  Future<CockpitDevelopmentSessionHandle> readSessionHandle(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'developmentSessionHandleNotFound',
        message: 'Development session handle JSON file does not exist.',
        details: <String, Object?>{'path': path},
      );
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidDevelopmentSessionHandleJson',
        message: 'Development session handle JSON must decode to an object.',
        details: <String, Object?>{'path': path},
      );
    }

    return CockpitDevelopmentSessionHandle.fromJson(
      cockpitNormalizeJsonKeys(Map<String, Object?>.from(decoded)),
    );
  }
}
