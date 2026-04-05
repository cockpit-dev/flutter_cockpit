import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_command_command.dart';
import 'package:test/test.dart';

void main() {
  test('run-command accepts app-json and minimal profile', () async {
    CockpitRunCommandRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        RunCommandCommand(
          stdoutSink: stdoutBuffer,
          runCommand: (request) async {
            capturedRequest = request;
            return CockpitRunCommandResult(
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

    final exitCode = await runner.run(<String>[
          'run-command',
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
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['command'], isA<Map<String, Object?>>());
    expect(stdoutBuffer.toString(), isNot(contains('\n  "')));
  });

  test('run-command writes pretty json files when output-json is used',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('cockpit_run_command');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final outputFile = File(p.join(tempDir.path, 'result.json'));
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        RunCommandCommand(
          stdoutSink: stdoutBuffer,
          runCommand: (_) async => CockpitRunCommandResult(
            command: const CockpitInteractiveCommandCore(
              commandId: 'tap-1',
              commandType: 'tap',
              success: true,
              durationMs: 42,
              usedCaptureFallback: false,
            ),
            artifacts: const <CockpitInteractiveArtifactDescriptor>[],
          ),
        ),
      );

    final exitCode = await runner.run(<String>[
          'run-command',
          '--base-url',
          'http://127.0.0.1:47331',
          '--command-json',
          jsonEncode(<String, Object?>{
            'commandId': 'tap-1',
            'commandType': 'tap',
          }),
          '--output-json',
          outputFile.path,
        ]) ??
        0;

    expect(exitCode, 0);
    expect(stdoutBuffer.toString(), isEmpty);
    final written = await outputFile.readAsString();
    expect(written, contains('\n  "command"'));
    final decoded = jsonDecode(written) as Map<String, Object?>;
    expect(decoded['command'], isA<Map<String, Object?>>());
  });
}
