import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_data.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/execute_remote_command_command.dart';
import 'package:test/test.dart';

void main() {
  test(
    'execute-remote-command parses inline JSON and writes result JSON',
    () async {
      CockpitExecuteRemoteCommandRequest? capturedRequest;
      final stdoutBuffer = StringBuffer();
      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(
          ExecuteRemoteCommandCommand(
            stdoutSink: stdoutBuffer,
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
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'execute-remote-command',
            '--stdout-format',
            'json',
            '--base-url',
            'http://127.0.0.1:47331',
            '--command-json',
            jsonEncode(<String, Object?>{
              'commandId': 'tap-1',
              'commandType': 'tap',
            }),
            '--profile',
            'minimal',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.command.commandId, 'tap-1');
      expect(capturedRequest?.resultProfile.name.jsonValue, 'minimal');
      final decoded =
          jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
      expect(decoded['command'], isA<Map<String, Object?>>());
    },
  );
}
