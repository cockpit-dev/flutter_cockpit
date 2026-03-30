export 'cockpit_application_service_exception.dart';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_session_lock.dart';
import 'cockpit_json_key_normalizer.dart';
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
    this.artifact,
    this.durationMs,
    this.failureReason,
    this.sessionHandle,
  });

  final CockpitRecordingState state;
  final CockpitRecordingPurpose? purpose;
  final CockpitRecordingKind? recordingKind;
  final CockpitInteractiveArtifactDescriptor? artifact;
  final int? durationMs;
  final String? failureReason;
  final CockpitRemoteSessionHandle? sessionHandle;

  Map<String, Object?> toJson() => <String, Object?>{
        'state': state.name,
        'purpose': purpose?.name,
        'recording_kind': recordingKind == null
            ? null
            : cockpitSnakeCaseEnumValue('recording_kind', recordingKind!.name),
        'artifact': artifact?.toJson(),
        'duration_ms': durationMs,
        'failure_reason': failureReason,
        'session_handle': cockpitSnakeCaseJsonValue(sessionHandle?.toJson()),
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
