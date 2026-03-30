export 'cockpit_application_service_exception.dart';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_interactive_session_lock.dart';
import 'cockpit_session_reference_resolver.dart';

typedef CockpitRemoteRecordingStarter = Future<CockpitRecordingSession>
    Function(
  Uri baseUri,
  CockpitRecordingRequest request,
);

final class CockpitStartRemoteRecordingRequest {
  const CockpitStartRemoteRecordingRequest({
    required this.recording,
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
  });

  final CockpitRecordingRequest recording;
  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
}

final class CockpitStartRemoteRecordingResult {
  const CockpitStartRemoteRecordingResult({
    required this.recordingSession,
    this.sessionHandle,
  });

  final CockpitRecordingSession recordingSession;
  final CockpitRemoteSessionHandle? sessionHandle;

  Map<String, Object?> toJson() => <String, Object?>{
        'recording_session': recordingSession.toJson(),
        'session_handle': sessionHandle?.toJson(),
      };
}

final class CockpitStartRemoteRecordingService {
  CockpitStartRemoteRecordingService({
    CockpitRemoteRecordingStarter? startRecording,
    CockpitSessionReferenceResolver? sessionReferenceResolver,
    CockpitInteractiveSessionLock? sessionLock,
  })  : _startRecording = startRecording ??
            ((baseUri, request) => CockpitRemoteSessionClient(
                  baseUri: baseUri,
                ).startRecording(request)),
        _sessionReferenceResolver =
            sessionReferenceResolver ?? CockpitSessionReferenceResolver(),
        _sessionLock = sessionLock ?? CockpitInteractiveSessionLock();

  final CockpitRemoteRecordingStarter _startRecording;
  final CockpitSessionReferenceResolver _sessionReferenceResolver;
  final CockpitInteractiveSessionLock _sessionLock;

  Future<CockpitStartRemoteRecordingResult> start(
    CockpitStartRemoteRecordingRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.androidDeviceId,
    );
    final recordingSession = await _sessionLock.run(
      resolved.baseUri.toString(),
      () => _startRecording(resolved.baseUri, request.recording),
    );
    return CockpitStartRemoteRecordingResult(
      recordingSession: recordingSession,
      sessionHandle: resolved.sessionHandle,
    );
  }
}
