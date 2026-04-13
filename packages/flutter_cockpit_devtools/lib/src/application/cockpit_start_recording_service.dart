import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import '../recording/cockpit_recording_strategy_resolver.dart';
import '../remote/cockpit_remote_session_client.dart';
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
    this.iosDeviceId,
  });

  final CockpitRecordingRequest recording;
  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final String? iosDeviceId;
}

typedef CockpitStartRecordingResult = CockpitStartRemoteRecordingResult;

final class CockpitStartRecordingService {
  CockpitStartRecordingService({
    CockpitStartRemoteRecordingService? startService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitRecordingStrategyResolver recordingStrategyResolver =
        const CockpitRecordingStrategyResolver(),
    CockpitSessionRegistry? registry,
  })  : _startService = startService ?? CockpitStartRemoteRecordingService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry),
        _recordingStrategyResolver = recordingStrategyResolver;

  final CockpitStartRemoteRecordingService _startService;
  final CockpitAppReferenceResolver _appReferenceResolver;
  final CockpitRecordingStrategyResolver _recordingStrategyResolver;

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
    final iosDeviceId = request.iosDeviceId ??
        (resolved.app?.platform == 'ios' ? resolved.app?.deviceId : null);
    if (iosDeviceId != null && iosDeviceId.isNotEmpty) {
      final adapter = _recordingStrategyResolver.resolve(
        platform: 'ios',
        recording: request.recording,
        client: CockpitRemoteSessionClient(baseUri: resolved.baseUri),
        iosDeviceId: iosDeviceId,
      );
      if (adapter != null) {
        final recordingSession =
            await adapter.startRecording(request.recording);
        return CockpitStartRecordingResult(recordingSession: recordingSession);
      }
    }
    return _startService.start(
      CockpitStartRemoteRecordingRequest(
        baseUri: resolved.baseUri,
        recording: request.recording,
      ),
    );
  }
}
