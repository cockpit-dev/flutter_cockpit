import 'cockpit_app_handle.dart';
import 'cockpit_app_reference_resolver.dart';
import 'cockpit_interactive_result_data.dart';
import '../recording/cockpit_recording_strategy_resolver.dart';
import '../remote/cockpit_remote_session_client.dart';
import 'cockpit_session_registry.dart';
import 'cockpit_stop_remote_recording_service.dart';

final class CockpitStopRecordingRequest {
  const CockpitStopRecordingRequest({
    this.appId,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.iosDeviceId,
  });

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final String? iosDeviceId;
}

typedef CockpitStopRecordingResult = CockpitStopRemoteRecordingResult;

final class CockpitStopRecordingService {
  CockpitStopRecordingService({
    CockpitStopRemoteRecordingService? stopService,
    CockpitAppReferenceResolver? appReferenceResolver,
    CockpitRecordingStrategyResolver recordingStrategyResolver =
        const CockpitRecordingStrategyResolver(),
    CockpitSessionRegistry? registry,
  })  : _stopService = stopService ?? CockpitStopRemoteRecordingService(),
        _appReferenceResolver = appReferenceResolver ??
            CockpitAppReferenceResolver(registry: registry),
        _recordingStrategyResolver = recordingStrategyResolver;

  final CockpitStopRemoteRecordingService _stopService;
  final CockpitAppReferenceResolver _appReferenceResolver;
  final CockpitRecordingStrategyResolver _recordingStrategyResolver;

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
    final iosDeviceId = request.iosDeviceId ??
        (resolved.app?.platform == 'ios' ? resolved.app?.deviceId : null);
    if (iosDeviceId != null && iosDeviceId.isNotEmpty) {
      final adapter = _recordingStrategyResolver.resolve(
        platform: 'ios',
        recording: true,
        client: CockpitRemoteSessionClient(baseUri: resolved.baseUri),
        iosDeviceId: iosDeviceId,
      );
      if (adapter != null) {
        final recordingResult = await adapter.stopRecording();
        final artifactRef = recordingResult.artifact;
        return CockpitStopRecordingResult(
          state: recordingResult.state,
          purpose: recordingResult.purpose,
          recordingKind: recordingResult.recordingKind,
          artifact: artifactRef == null
              ? null
              : CockpitInteractiveArtifactDescriptor(
                  role: artifactRef.role,
                  relativePath: artifactRef.relativePath,
                  byteLength: recordingResult.bytes?.length,
                  sourcePath: recordingResult.sourceFilePath,
                ),
          durationMs: recordingResult.durationMs,
          failureReason: recordingResult.failureReason,
        );
      }
    }
    return _stopService.stop(
      CockpitStopRemoteRecordingRequest(baseUri: resolved.baseUri),
    );
  }
}
