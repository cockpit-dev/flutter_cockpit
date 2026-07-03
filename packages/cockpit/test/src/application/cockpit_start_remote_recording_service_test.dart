import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_start_remote_recording_service.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitStartRemoteRecordingService', () {
    test('starts recording and returns structured session data', () async {
      CockpitRecordingRequest? capturedRequest;
      final service = CockpitStartRemoteRecordingService(
        startRecording: (_, request) async {
          capturedRequest = request;
          return CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          );
        },
      );

      final result = await service.start(
        CockpitStartRemoteRecordingRequest(
          sessionHandle: _sessionHandle(),
          recording: const CockpitRecordingRequest(
            purpose: CockpitRecordingPurpose.acceptance,
            name: 'debug-pass',
          ),
        ),
      );

      expect(capturedRequest?.name, 'debug-pass');
      expect(result.recordingSession.state, CockpitRecordingState.recording);
      expect(result.sessionHandle?.toJson(), _sessionHandle().toJson());
    });
  });
}

CockpitRemoteSessionHandle _sessionHandle() {
  return CockpitRemoteSessionHandle(
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    appId: 'dev.cockpit.demo',
    host: '127.0.0.1',
    hostPort: 47331,
    devicePort: 47331,
    baseUrl: 'http://127.0.0.1:47331',
    launchedAt: DateTime.utc(2026, 3, 30),
  );
}
