import 'dart:io';

import 'package:path/path.dart' as p;

import '../development/cockpit_development_session_status.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_compact_json.dart';
import 'cockpit_reload_development_session_service.dart';
import 'cockpit_session_registry.dart';

final class CockpitHotReloadRequest {
  const CockpitHotReloadRequest({this.appId, this.app, this.appHandlePath});

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
}

final class CockpitHotReloadResult {
  const CockpitHotReloadResult({
    required this.app,
    required this.status,
    this.appJsonPath,
  });

  final CockpitAppHandle app;
  final CockpitDevelopmentSessionStatus status;
  final String? appJsonPath;

  Map<String, Object?> toJson() => <String, Object?>{
    'app': app.toJson(),
    'status': status.toJson(),
    if (appJsonPath != null) 'appJsonPath': appJsonPath,
  };
}

final class CockpitHotReloadService {
  CockpitHotReloadService({
    CockpitReloadDevelopmentSessionService? reloadService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
  }) : _reloadService =
           reloadService ?? CockpitReloadDevelopmentSessionService(),
       _appReferenceResolver =
           appReferenceResolver ??
           CockpitAppReferenceResolver(registry: registry),
       _registry = registry;

  final CockpitReloadDevelopmentSessionService _reloadService;
  final CockpitAppReferenceResolver _appReferenceResolver;
  final CockpitSessionRegistry? _registry;

  Future<CockpitHotReloadResult> reload(CockpitHotReloadRequest request) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
    );
    final developmentHandle =
        resolved.app?.developmentSession ?? resolved.developmentRecord?.handle;
    if (developmentHandle == null) {
      throw const CockpitApplicationServiceException(
        code: 'hotReloadUnavailable',
        message: 'Hot reload is only available for development apps.',
      );
    }
    final reloaded = await _reloadService.reload(
      CockpitReloadDevelopmentSessionRequest(
        mode: CockpitDevelopmentReloadMode.hotReload,
        sessionHandle: developmentHandle,
      ),
    );
    _registry?.recordDevelopmentSession(
      handle: reloaded.sessionHandle,
      status: reloaded.status,
      supervisorLogPath: resolved.developmentRecord?.supervisorLogPath,
    );
    final app = CockpitAppHandle.fromDevelopmentSession(
      reloaded.sessionHandle,
      supervisorLogPath:
          resolved.app?.supervisorLogPath ??
          resolved.developmentRecord?.supervisorLogPath,
    );
    final appJsonPath = await _persistAppIfRequested(
      path: request.appHandlePath,
      app: app,
    );
    return CockpitHotReloadResult(
      app: app,
      status: reloaded.status,
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
    await file.writeAsString(cockpitPrettyJsonText(app.toJson()));
    return p.normalize(file.path);
  }
}
