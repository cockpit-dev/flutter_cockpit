import 'dart:convert';
import 'dart:io';

import '../remote/cockpit_android_port_forwarder.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_session_registry.dart';

final class CockpitResolvedAppReference {
  const CockpitResolvedAppReference({
    required this.baseUri,
    this.app,
    this.developmentRecord,
    this.remoteRecord,
  });

  final Uri baseUri;
  final CockpitAppHandle? app;
  final CockpitDevelopmentSessionRecord? developmentRecord;
  final CockpitRemoteSessionRecord? remoteRecord;
}

final class CockpitAppReferenceResolver {
  CockpitAppReferenceResolver({
    CockpitSessionRegistry? registry,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
  })  : _registry = registry,
        _portForwarder = portForwarder;

  final CockpitSessionRegistry? _registry;
  final CockpitAndroidPortForwarder _portForwarder;

  Future<CockpitResolvedAppReference> resolve({
    String? appId,
    CockpitAppHandle? app,
    String? appHandlePath,
    Uri? baseUri,
    String? androidDeviceId,
  }) async {
    if (app != null) {
      return CockpitResolvedAppReference(baseUri: app.baseUri, app: app);
    }

    if (appHandlePath != null && appHandlePath.isNotEmpty) {
      final resolvedApp = await readAppHandle(appHandlePath);
      final registry = _registry;
      final developmentRecord =
          registry?.developmentSessionByAppId(resolvedApp.appId);
      final remoteRecord = registry?.remoteSessionByAppId(resolvedApp.appId);
      return CockpitResolvedAppReference(
        baseUri: resolvedApp.baseUri,
        app: resolvedApp,
        developmentRecord: developmentRecord,
        remoteRecord: remoteRecord,
      );
    }

    if (appId != null && appId.isNotEmpty) {
      final registry = _registry;
      if (registry == null) {
        throw const CockpitApplicationServiceException(
          code: 'appLookupUnavailable',
          message: 'App lookup by app_id requires a session registry.',
        );
      }
      final developmentRecord = registry.developmentSessionByAppId(appId);
      if (developmentRecord != null) {
        final app = CockpitAppHandle.fromDevelopmentSession(
          developmentRecord.handle,
        );
        return CockpitResolvedAppReference(
          baseUri: app.baseUri,
          app: app,
          developmentRecord: developmentRecord,
        );
      }
      final remoteRecord = registry.remoteSessionByAppId(appId);
      if (remoteRecord != null) {
        final app = CockpitAppHandle.fromRemoteSession(remoteRecord.handle);
        return CockpitResolvedAppReference(
          baseUri: app.baseUri,
          app: app,
          remoteRecord: remoteRecord,
        );
      }
      throw CockpitApplicationServiceException(
        code: 'unknownAppId',
        message: 'Unknown app_id.',
        details: <String, Object?>{'app_id': appId},
      );
    }

    if (baseUri != null) {
      final deviceId = androidDeviceId;
      if (deviceId == null || deviceId.isEmpty) {
        return CockpitResolvedAppReference(baseUri: baseUri);
      }
      final hostPort = await _portForwarder.ensureForwarded(
        deviceId: deviceId,
        preferredHostPort: baseUri.port,
        devicePort: baseUri.port,
      );
      return CockpitResolvedAppReference(
        baseUri: baseUri.replace(port: hostPort),
      );
    }

    throw const CockpitApplicationServiceException(
      code: 'missingAppReference',
      message:
          'An app_id, app handle, app handle path, or base URI is required.',
    );
  }

  Future<CockpitAppHandle> readAppHandle(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'appHandleNotFound',
        message: 'App handle JSON file does not exist.',
        details: <String, Object?>{'path': path},
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidAppHandleJson',
        message: 'App handle JSON must decode to an object.',
        details: <String, Object?>{'path': path},
      );
    }
    return CockpitAppHandle.fromJson(Map<String, Object?>.from(decoded));
  }
}
