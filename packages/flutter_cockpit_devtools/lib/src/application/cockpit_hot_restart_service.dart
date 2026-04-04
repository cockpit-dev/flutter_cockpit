import 'dart:io';

import 'package:path/path.dart' as p;

import '../development/cockpit_development_session_status.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_json_key_normalizer.dart';
import 'cockpit_reload_development_session_service.dart';
import 'cockpit_session_registry.dart';

final class CockpitHotRestartRequest {
  const CockpitHotRestartRequest({
    this.appId,
    this.app,
    this.appHandlePath,
  });

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
}

final class CockpitHotRestartResult {
  const CockpitHotRestartResult({
    required this.app,
    required this.status,
    this.appJsonPath,
  });

  final CockpitAppHandle app;
  final CockpitDevelopmentSessionStatus status;
  final String? appJsonPath;

  Map<String, Object?> toJson() => <String, Object?>{
        'app': app.toJson(),
        'status': (status.toJson()),
        'appJsonPath': appJsonPath,
      };
}

final class CockpitHotRestartService {
  CockpitHotRestartService({
    CockpitReloadDevelopmentSessionService? reloadService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
  })  : _reloadService =
            reloadService ?? CockpitReloadDevelopmentSessionService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry),
        _registry = registry;

  final CockpitReloadDevelopmentSessionService _reloadService;
  final CockpitAppReferenceResolver _appReferenceResolver;
  final CockpitSessionRegistry? _registry;

  Future<CockpitHotRestartResult> restart(
    CockpitHotRestartRequest request,
  ) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
    );
    final developmentHandle =
        resolved.app?.developmentSession ?? resolved.developmentRecord?.handle;
    if (developmentHandle == null) {
      throw const CockpitApplicationServiceException(
        code: 'hotRestartUnavailable',
        message: 'Hot restart is only available for development apps.',
      );
    }
    final restarted = await _reloadService.reload(
      CockpitReloadDevelopmentSessionRequest(
        mode: CockpitDevelopmentReloadMode.hotRestart,
        sessionHandle: developmentHandle,
      ),
    );
    _registry?.recordDevelopmentSession(
      handle: restarted.sessionHandle,
      status: restarted.status,
      supervisorLogPath: resolved.developmentRecord?.supervisorLogPath,
    );
    final app = CockpitAppHandle.fromDevelopmentSession(
      restarted.sessionHandle,
      supervisorLogPath: resolved.app?.supervisorLogPath ??
          resolved.developmentRecord?.supervisorLogPath,
    );
    final appJsonPath = await _persistAppIfRequested(
      path: request.appHandlePath,
      app: app,
    );
    return CockpitHotRestartResult(
      app: app,
      status: restarted.status,
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
