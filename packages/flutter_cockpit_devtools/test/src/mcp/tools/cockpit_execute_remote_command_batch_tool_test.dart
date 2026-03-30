import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_batch_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_execute_remote_command_batch_tool.dart';
import 'package:test/test.dart';

void main() {
  test('execute_remote_command_batch parses batch arguments', () async {
    CockpitExecuteRemoteCommandBatchRequest? capturedRequest;
    final tool = CockpitExecuteRemoteCommandBatchTool(
      execute: (request) async {
        capturedRequest = request;
        return const CockpitExecuteRemoteCommandBatchResult(
          results: <CockpitExecuteRemoteCommandResult>[],
          summary: CockpitExecuteRemoteCommandBatchSummary(
            totalCount: 0,
            successCount: 0,
            failureCount: 0,
            stoppedEarly: false,
          ),
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
      'commands': <Object?>[
        <String, Object?>{
          'commandId': 'tap-1',
          'commandType': 'tap',
        },
      ],
      'default_result_profile': 'inspect',
      'fail_fast': false,
    });

    expect(capturedRequest?.commands.length, 1);
    expect(capturedRequest?.defaultResultProfile.name.jsonValue, 'inspect');
    expect(capturedRequest?.failFast, isFalse);
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
