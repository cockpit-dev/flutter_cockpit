import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_session_registry.dart';
import 'cockpit_start_remote_recording_service.dart';

final class CockpitStartRecordingRequest {
  const CockpitStartRecordingRequest({
    required this.recording,
    this.appId,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
  });

  final CockpitRecordingRequest recording;
  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
}

typedef CockpitStartRecordingResult = CockpitStartRemoteRecordingResult;

final class CockpitStartRecordingService {
  CockpitStartRecordingService({
    CockpitStartRemoteRecordingService? startService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitSessionRegistry? registry,
  })  : _startService = startService ?? CockpitStartRemoteRecordingService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry);

  final CockpitStartRemoteRecordingService _startService;
  final CockpitAppReferenceResolver _appReferenceResolver;

  Future<CockpitStartRecordingResult> start(
    CockpitStartRecordingRequest request,
  ) async {
    final resolved = await _appReferenceResolver.resolve(
      appId: request.appId,
      app: request.app,
      appHandlePath: request.appHandlePath,
      baseUri: request.baseUri,
      androidDeviceId: request.androidDeviceId,
    );
    return _startService.start(
      CockpitStartRemoteRecordingRequest(
        baseUri: resolved.baseUri,
        recording: request.recording,
      ),
    );
  }
}
