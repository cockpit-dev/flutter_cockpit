export 'cockpit_application_service_exception.dart';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_session_lock.dart';
import 'cockpit_session_reference_resolver.dart';

typedef CockpitRemoteRecordingStopper = Future<CockpitRecordingResult> Function(
  Uri baseUri,
);

final class CockpitStopRemoteRecordingRequest {
  const CockpitStopRemoteRecordingRequest({
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
  });

  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
}

final class CockpitStopRemoteRecordingResult {
  const CockpitStopRemoteRecordingResult({
    required this.state,
    this.purpose,
    this.recordingKind,
    this.requestedMode,
    this.requestedLayer,
    this.effectiveLayer,
    this.fallbackUsed = false,
    this.fallbackReason,
    this.artifact,
    this.durationMs,
    this.failureReason,
    this.sessionHandle,
  });

  final CockpitRecordingState state;
  final CockpitRecordingPurpose? purpose;
  final CockpitRecordingKind? recordingKind;
  final CockpitRecordingMode? requestedMode;
  final CockpitRecordingLayer? requestedLayer;
  final CockpitRecordingLayer? effectiveLayer;
  final bool fallbackUsed;
  final String? fallbackReason;
  final CockpitInteractiveArtifactDescriptor? artifact;
  final int? durationMs;
  final String? failureReason;
  final CockpitRemoteSessionHandle? sessionHandle;

  Map<String, Object?> toJson() => <String, Object?>{
        'state': state.name,
        if (purpose != null) 'purpose': purpose!.name,
        if (recordingKind != null) 'recordingKind': recordingKind!.name,
        if (requestedMode != null) 'requestedMode': requestedMode!.jsonValue,
        if (requestedLayer != null) 'requestedLayer': requestedLayer!.jsonValue,
        if (effectiveLayer != null) 'effectiveLayer': effectiveLayer!.jsonValue,
        if (fallbackUsed) 'fallbackUsed': fallbackUsed,
        if (fallbackReason != null) 'fallbackReason': fallbackReason,
        if (artifact != null) 'artifact': artifact!.toJson(),
        if (durationMs != null) 'durationMs': durationMs,
        if (failureReason != null) 'failureReason': failureReason,
        if (sessionHandle != null) 'sessionHandle': sessionHandle!.toJson(),
      };
}

final class CockpitStopRemoteRecordingService {
  CockpitStopRemoteRecordingService({
    CockpitRemoteRecordingStopper? stopRecording,
    CockpitSessionReferenceResolver? sessionReferenceResolver,
    CockpitInteractiveSessionLock? sessionLock,
  })  : _stopRecording = stopRecording ??
            ((baseUri) => CockpitRemoteSessionClient(
                  baseUri: baseUri,
                ).stopRecording()),
        _sessionReferenceResolver =
            sessionReferenceResolver ?? CockpitSessionReferenceResolver(),
        _sessionLock = sessionLock ?? CockpitInteractiveSessionLock();

  final CockpitRemoteRecordingStopper _stopRecording;
  final CockpitSessionReferenceResolver _sessionReferenceResolver;
  final CockpitInteractiveSessionLock _sessionLock;

  Future<CockpitStopRemoteRecordingResult> stop(
    CockpitStopRemoteRecordingRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.androidDeviceId,
    );
    final recordingResult = await _sessionLock.run(
      resolved.baseUri.toString(),
      () => _stopRecording(resolved.baseUri),
    );
    final artifactRef = recordingResult.artifact;
    return CockpitStopRemoteRecordingResult(
      state: recordingResult.state,
      purpose: recordingResult.purpose,
      recordingKind: recordingResult.recordingKind,
      requestedMode: recordingResult.requestedMode,
      requestedLayer: recordingResult.requestedLayer,
      effectiveLayer: recordingResult.effectiveLayer,
      fallbackUsed: recordingResult.fallbackUsed,
      fallbackReason: recordingResult.fallbackReason,
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
      sessionHandle: resolved.sessionHandle,
    );
  }
}
