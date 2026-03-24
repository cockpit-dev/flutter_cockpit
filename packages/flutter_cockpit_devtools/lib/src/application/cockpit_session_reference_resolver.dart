import 'dart:convert';
import 'dart:io';

import '../remote/cockpit_android_port_forwarder.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_application_service_exception.dart';

final class CockpitResolvedSessionReference {
  const CockpitResolvedSessionReference({
    required this.baseUri,
    this.sessionHandle,
  });

  final Uri baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
}

final class CockpitSessionReferenceResolver {
  CockpitSessionReferenceResolver({
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
  }) : _portForwarder = portForwarder;

  final CockpitAndroidPortForwarder _portForwarder;

  Future<CockpitResolvedSessionReference> resolve({
    Uri? baseUri,
    CockpitRemoteSessionHandle? sessionHandle,
    String? sessionHandlePath,
    String? androidDeviceId,
  }) async {
    if (sessionHandle != null) {
      return CockpitResolvedSessionReference(
        baseUri: sessionHandle.baseUri,
        sessionHandle: sessionHandle,
      );
    }

    if (sessionHandlePath != null && sessionHandlePath.isNotEmpty) {
      final resolvedHandle = await readSessionHandle(sessionHandlePath);
      return CockpitResolvedSessionReference(
        baseUri: resolvedHandle.baseUri,
        sessionHandle: resolvedHandle,
      );
    }

    if (baseUri != null) {
      final deviceId = androidDeviceId;
      if (deviceId == null || deviceId.isEmpty) {
        return CockpitResolvedSessionReference(baseUri: baseUri);
      }

      final hostPort = await _portForwarder.ensureForwarded(
        deviceId: deviceId,
        preferredHostPort: baseUri.port,
        devicePort: baseUri.port,
      );
      return CockpitResolvedSessionReference(
        baseUri: baseUri.replace(port: hostPort),
      );
    }

    throw const CockpitApplicationServiceException(
      code: 'missingSessionReference',
      message: 'A session handle, handle path, or base URI is required.',
    );
  }

  Future<CockpitRemoteSessionHandle> readSessionHandle(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'sessionHandleNotFound',
        message: 'Session handle JSON file does not exist.',
        details: <String, Object?>{'path': path},
      );
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidSessionHandleJson',
        message: 'Session handle JSON must decode to an object.',
        details: <String, Object?>{'path': path},
      );
    }
    return CockpitRemoteSessionHandle.fromJson(
      Map<String, Object?>.from(decoded),
    );
  }
}
