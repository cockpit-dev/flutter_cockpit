import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_interactive_result_data.dart';
import 'package:cockpit/src/application/cockpit_stop_remote_recording_service.dart';
import 'package:cockpit/src/mcp/tools/cockpit_stop_remote_recording_tool.dart';
import 'package:test/test.dart';

void main() {
  test('stop_remote_recording returns structured content', () async {
    final tool = CockpitStopRemoteRecordingTool(
      stop: (_) async => const CockpitStopRemoteRecordingResult(
        state: CockpitRecordingState.completed,
        artifact: CockpitInteractiveArtifactDescriptor(
          role: 'recording',
          relativePath: 'recordings/final.mp4',
          byteLength: 4,
        ),
      ),
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
    });

    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
