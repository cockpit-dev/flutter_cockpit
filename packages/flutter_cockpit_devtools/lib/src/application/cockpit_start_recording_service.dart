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
  }) : _startService = startService ?? CockpitStartRemoteRecordingService(),
       _appReferenceResolver =
           appReferenceResolver ??
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
    final platform = _resolvedPlatform(
      app: resolved.app,
      androidDeviceId: request.androidDeviceId,
      iosDeviceId: request.iosDeviceId,
    );
    if (platform != null) {
      final resolution = _recordingStrategyResolver.resolveDetailed(
        platform: platform,
        recording: request.recording,
        client: CockpitRemoteSessionClient(baseUri: resolved.baseUri),
        sessionHandle: resolved.app?.remoteSession,
        androidDeviceId:
            request.androidDeviceId ??
            (resolved.app?.platform == 'android'
                ? resolved.app?.deviceId
                : null),
        iosDeviceId:
            request.iosDeviceId ??
            (resolved.app?.platform == 'ios' ? resolved.app?.deviceId : null),
        platformAppId:
            resolved.app?.platformAppId ??
            resolved.app?.remoteSession?.effectivePlatformAppId,
        processId:
            resolved.app?.processId ?? resolved.app?.remoteSession?.processId,
      );
      final adapter = resolution?.adapter;
      if (adapter != null) {
        final recordingSession = await adapter.startRecording(
          request.recording,
        );
        return CockpitStartRecordingResult(
          recordingSession: recordingSession,
          sessionHandle: resolved.app?.remoteSession,
        );
      }
      if (resolution?.unsupportedReason != null) {
        throw CockpitApplicationServiceException(
          code: 'recordingStrategyUnavailable',
          message: resolution!.unsupportedReason!,
          details: <String, Object?>{
            'platform': platform,
            'baseUrl': resolved.baseUri.toString(),
            'recording': request.recording.toJson(),
          },
        );
      }
    }
    return _startService.start(
      CockpitStartRemoteRecordingRequest(
        baseUri: resolved.baseUri,
        sessionHandle: resolved.app?.remoteSession,
        recording: request.recording,
      ),
    );
  }

  String? _resolvedPlatform({
    required CockpitAppHandle? app,
    required String? androidDeviceId,
    required String? iosDeviceId,
  }) {
    final appPlatform = app?.platform;
    if (appPlatform != null && appPlatform.isNotEmpty) {
      return appPlatform;
    }
    if (iosDeviceId != null && iosDeviceId.isNotEmpty) {
      return 'ios';
    }
    if (androidDeviceId != null && androidDeviceId.isNotEmpty) {
      return 'android';
    }
    return null;
  }
}
