import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_stop_remote_recording_service.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitStopRemoteRecordingService', () {
    test('stops recording and returns artifact metadata', () async {
      final service = CockpitStopRemoteRecordingService(
        stopRecording: (_) async => CockpitRecordingResult(
          state: CockpitRecordingState.completed,
          purpose: CockpitRecordingPurpose.acceptance,
          recordingKind: CockpitRecordingKind.nativeScreen,
          artifact: const CockpitArtifactRef(
            role: 'recording',
            relativePath: 'recordings/final.mp4',
          ),
          durationMs: 1200,
          bytes: <int>[1, 2, 3, 4],
          sourceFilePath: '/tmp/final.mp4',
        ),
      );

      final result = await service.stop(
        CockpitStopRemoteRecordingRequest(
          sessionHandle: _sessionHandle(),
        ),
      );

      expect(result.state, CockpitRecordingState.completed);
      expect(result.artifact?.relativePath, 'recordings/final.mp4');
      expect(result.artifact?.byteLength, 4);
      expect(result.artifact?.sourcePath, '/tmp/final.mp4');
    });

    test('preserves structured failure reasons', () async {
      final service = CockpitStopRemoteRecordingService(
        stopRecording: (_) async => CockpitRecordingResult(
          state: CockpitRecordingState.failed,
          purpose: CockpitRecordingPurpose.acceptance,
          failureReason: 'unsupported_recording',
        ),
      );

      final result = await service.stop(
        CockpitStopRemoteRecordingRequest(
          sessionHandle: _sessionHandle(),
        ),
      );

      expect(result.state, CockpitRecordingState.failed);
      expect(result.failureReason, 'unsupported_recording');
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
