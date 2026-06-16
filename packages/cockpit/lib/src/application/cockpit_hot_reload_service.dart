import '../development/cockpit_development_session_status.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_development_reload_executor.dart';
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
    final outcome = await cockpitExecuteDevelopmentReload(
      mode: CockpitDevelopmentReloadMode.hotReload,
      unavailableCode: 'hotReloadUnavailable',
      unavailableMessage: 'Hot reload is only available for development apps.',
      reloadService: _reloadService,
      appReferenceResolver: _appReferenceResolver,
      registry: _registry,
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
    );
    return CockpitHotReloadResult(
      app: outcome.app,
      status: outcome.status,
      appJsonPath: outcome.appJsonPath,
    );
  }
}
