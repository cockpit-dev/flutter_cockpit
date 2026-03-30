import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_batch_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/execute_remote_command_batch_command.dart';
import 'package:test/test.dart';

void main() {
  test('execute-remote-command-batch parses batch JSON and overrides',
      () async {
    CockpitExecuteRemoteCommandBatchRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        ExecuteRemoteCommandBatchCommand(
          stdoutSink: stdoutBuffer,
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
        ),
      );

    final exitCode = await runner.run(<String>[
          'execute-remote-command-batch',
          '--base-url',
          'http://127.0.0.1:47331',
          '--commands-json',
          jsonEncode(<Object?>[
            <String, Object?>{
              'commandId': 'tap-1',
              'commandType': 'tap',
            },
            <String, Object?>{
              'command': <String, Object?>{
                'commandId': 'tap-2',
                'commandType': 'tap',
              },
              'resultProfile': 'compact',
            },
          ]),
          '--default-profile',
          'inspect',
          '--no-fail-fast',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.commands.length, 2);
    expect(capturedRequest?.defaultResultProfile.name.jsonValue, 'inspect');
    expect(capturedRequest?.failFast, isFalse);
    expect(
      capturedRequest?.commands[1].resultProfile?.name.jsonValue,
      'compact',
    );
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['summary'], isA<Map<String, Object?>>());
  });
}
