import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_data.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_execute_remote_command_tool.dart';
import 'package:test/test.dart';

void main() {
  test('execute_remote_command parses command arguments and returns content',
      () async {
    CockpitExecuteRemoteCommandRequest? capturedRequest;
    final tool = CockpitExecuteRemoteCommandTool(
      execute: (request) async {
        capturedRequest = request;
        return CockpitExecuteRemoteCommandResult(
          command: const CockpitInteractiveCommandCore(
            commandId: 'tap-1',
            commandType: 'tap',
            success: true,
            durationMs: 42,
            usedCaptureFallback: false,
          ),
          artifacts: const <CockpitInteractiveArtifactDescriptor>[],
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'session_handle': <String, Object?>{
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
      'command': <String, Object?>{
        'commandId': 'tap-1',
        'commandType': 'tap',
      },
      'result_profile': 'compact',
    });

    expect(capturedRequest?.command.commandId, 'tap-1');
    expect(capturedRequest?.resultProfile.name.jsonValue, 'compact');
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
