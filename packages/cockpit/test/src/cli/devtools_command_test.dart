import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cockpit/src/cli/commands/devtools_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('devtools command help documents latest scope', () {
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        DevtoolsCommand(
          stdoutSink: StringBuffer(),
          waitForShutdown: () async {},
        ),
      );
    final command = runner.commands['devtools']!;

    expect(
      command.usage,
      contains(
        'Initial history scope for the board URL. Use current, latest, all, or a concrete session/task scope id.',
      ),
    );
  });

  test(
    'devtools command starts server and prints the local dashboard URL',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_command_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      File(
        p.join(tempDir.path, 'index.json'),
      ).writeAsStringSync('{"schemaVersion":1,"runCount":0,"runs":[]}');
      final output = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          DevtoolsCommand(stdoutSink: output, waitForShutdown: () async {}),
        );

      final exitCode =
          await runner.run(<String>[
            'devtools',
            '--history-root',
            tempDir.path,
            '--token',
            'secret',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(output.toString(), contains('cockpit.v=1'));
      expect(output.toString(), contains('command=devtools'));
      expect(output.toString(), contains('url=http://127.0.0.1:'));
      expect(output.toString(), contains('token=secret'));
      expect(output.toString(), contains('scope=current'));
      expect(output.toString(), contains('historyRoot=${tempDir.path}'));
    },
  );

  test('devtools command supports json stdout format', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_devtools_command_json_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        DevtoolsCommand(stdoutSink: output, waitForShutdown: () async {}),
      );

    final exitCode =
        await runner.run(<String>[
          'devtools',
          '--history-root',
          tempDir.path,
          '--token',
          'secret',
          '--stdout-format',
          'json',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['command'], 'devtools');
    expect(decoded['url'], startsWith('http://127.0.0.1:'));
    expect(decoded['historyRoot'], tempDir.path);
    expect(decoded['scope'], 'current');
    expect(decoded['stop'], 'press Ctrl-C or terminate this process');
  });

  test(
    'devtools command writes payload to file and prints only output path',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_devtools_command_output_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final outputPath = p.join(tempDir.path, 'devtools.json');
      final output = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          DevtoolsCommand(stdoutSink: output, waitForShutdown: () async {}),
        );

      final exitCode =
          await runner.run(<String>[
            'devtools',
            '--history-root',
            tempDir.path,
            '--token',
            'secret',
            '--output',
            outputPath,
            '--output-format',
            'json',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(output.toString().trim(), 'output=$outputPath');
      final decoded =
          jsonDecode(File(outputPath).readAsStringSync())
              as Map<String, Object?>;
      expect(decoded['command'], 'devtools');
      expect(decoded['historyRoot'], tempDir.path);
      expect(decoded['url'], contains('token=secret'));
    },
  );
}
