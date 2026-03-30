import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_session_registry.dart';
import 'cockpit_stop_remote_recording_service.dart';

final class CockpitStopRecordingRequest {
  const CockpitStopRecordingRequest({
    this.appId,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
  });

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
}

typedef CockpitStopRecordingResult = CockpitStopRemoteRecordingResult;

final class CockpitStopRecordingService {
  CockpitStopRecordingService({
    CockpitStopRemoteRecordingService? stopService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
  })  : _stopService = stopService ?? CockpitStopRemoteRecordingService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry);

  final CockpitStopRemoteRecordingService _stopService;
  final CockpitAppReferenceResolver _appReferenceResolver;

  Future<CockpitStopRecordingResult> stop(
    CockpitStopRecordingRequest request,
  ) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
      baseUri: request.baseUri,
      androidDeviceId: request.androidDeviceId,
    );
    return _stopService.stop(
      CockpitStopRemoteRecordingRequest(baseUri: resolved.baseUri),
    );
  }
}
