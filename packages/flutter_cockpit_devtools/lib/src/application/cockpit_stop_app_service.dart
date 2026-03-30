import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../development/cockpit_development_session_status.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_json_key_normalizer.dart';
import 'cockpit_session_registry.dart';
import 'cockpit_stop_development_session_service.dart';

final class CockpitStopAppRequest {
  const CockpitStopAppRequest({
    this.appId,
    this.app,
    this.appHandlePath,
  });

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
}

final class CockpitStopAppResult {
  const CockpitStopAppResult({
    required this.app,
    required this.status,
    this.appJsonPath,
  });

  final CockpitAppHandle app;
  final CockpitDevelopmentSessionStatus status;
  final String? appJsonPath;

  Map<String, Object?> toJson() => <String, Object?>{
        'app': app.toJson(),
        'status': cockpitSnakeCaseJsonValue(status.toJson()),
        'app_json_path': appJsonPath,
      };
}

final class CockpitStopAppService {
  CockpitStopAppService({
    CockpitStopDevelopmentSessionService? stopService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
  })  : _stopService = stopService ?? CockpitStopDevelopmentSessionService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry),
        _registry = registry;

  final CockpitStopDevelopmentSessionService _stopService;
  final CockpitAppReferenceResolver _appReferenceResolver;
  final CockpitSessionRegistry? _registry;

  Future<CockpitStopAppResult> stop(CockpitStopAppRequest request) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
    );
    final developmentHandle =
        resolved.app?.developmentSession ?? resolved.developmentRecord?.handle;
    if (developmentHandle == null) {
      throw const CockpitApplicationServiceException(
        code: 'stopAppUnavailable',
        message: 'Stop is only available for development apps.',
      );
    }
    final stopped = await _stopService.stop(
      CockpitStopDevelopmentSessionRequest(sessionHandle: developmentHandle),
    );
    _registry?.removeDevelopmentSession(
      stopped.sessionHandle.developmentSessionId,
    );
    final app = CockpitAppHandle.fromDevelopmentSession(
      stopped.sessionHandle,
      supervisorLogPath: resolved.app?.supervisorLogPath ??
          resolved.developmentRecord?.supervisorLogPath,
    );
    final appJsonPath = await _persistAppIfRequested(
      path: request.appHandlePath,
      app: app,
    );
    return CockpitStopAppResult(
      app: app,
      status: stopped.status,
      appJsonPath: appJsonPath,
    );
  }

  Future<String?> _persistAppIfRequested({
    required String? path,
    required CockpitAppHandle app,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(app.toJson()),
    );
    return p.normalize(file.path);
  }
}
