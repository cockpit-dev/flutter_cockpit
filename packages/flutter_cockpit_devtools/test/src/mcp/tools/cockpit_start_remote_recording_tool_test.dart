import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_start_remote_recording_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_start_remote_recording_tool.dart';
import 'package:test/test.dart';

void main() {
  test('start_remote_recording parses recording input', () async {
    CockpitStartRemoteRecordingRequest? capturedRequest;
    final tool = CockpitStartRemoteRecordingTool(
      start: (request) async {
        capturedRequest = request;
        return CockpitStartRemoteRecordingResult(
          recordingSession: CockpitRecordingSession(
            request: request.recording,
            state: CockpitRecordingState.recording,
          ),
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'sessionHandle': <String, Object?>{
        'platform': 'macos',
        'deviceId': 'macos',
        'projectDir': '/workspace',
        'target': 'cockpit/main.dart',
        'appId': 'dev.cockpit.demo',
        'host': '127.0.0.1',
        'hostPort': 47331,
        'devicePort': 47331,
        'baseUrl': 'http://127.0.0.1:47331',
        'launchedAt': '2026-03-30T00:00:00.000Z',
      },
      'recording': <String, Object?>{
        'purpose': 'acceptance',
        'name': 'debug-pass',
      },
    });

    expect(capturedRequest?.recording.name, 'debug-pass');
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
