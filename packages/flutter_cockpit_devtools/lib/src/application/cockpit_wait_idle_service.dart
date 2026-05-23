import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_session_registry.dart';
import 'cockpit_wait_remote_ui_idle_service.dart';

final class CockpitWaitIdleRequest {
  const CockpitWaitIdleRequest({
    this.appId,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.quietWindow = const Duration(milliseconds: 96),
    this.timeout = const Duration(milliseconds: 1600),
    this.includeNetworkIdle = true,
  });

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final Duration quietWindow;
  final Duration timeout;
  final bool includeNetworkIdle;
}

typedef CockpitWaitIdleResult = CockpitWaitRemoteUiIdleResult;

final class CockpitWaitIdleService {
  CockpitWaitIdleService({
    CockpitWaitRemoteUiIdleService? waitService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
  })  : _waitService = waitService ?? CockpitWaitRemoteUiIdleService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry);

  final CockpitWaitRemoteUiIdleService _waitService;
  final CockpitAppReferenceResolver _appReferenceResolver;

  Future<CockpitWaitIdleResult> wait(CockpitWaitIdleRequest request) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
      baseUri: request.baseUri,
      androidDeviceId: request.androidDeviceId,
    );
    return _waitService.wait(
      CockpitWaitRemoteUiIdleRequest(
        baseUri: resolved.baseUri,
        sessionHandle: resolved.app?.remoteSession,
        quietWindow: request.quietWindow,
        timeout: request.timeout,
        includeNetworkIdle: request.includeNetworkIdle,
      ),
    );
  }
}
