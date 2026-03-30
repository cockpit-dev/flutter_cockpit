import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/bundle_session_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('bundle-session writes a bundle from exported session json', () async {
    final tempDir = await Directory.systemTemp.createTemp('cockpit_cli_test');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final sessionFile = File(p.join(tempDir.path, 'session.json'));
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-001',
        taskId: 'task-login',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 5),
        artifactRefs: const [],
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    await sessionFile.writeAsString(jsonEncode(bundle.toJson()));

    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(BundleSessionCommand());
    final exitCode = await runner.run([
      'bundle-session',
      '--session-json',
      sessionFile.path,
      '--output-root',
      tempDir.path,
    ]);
    final outputDirectories = tempDir
        .listSync()
        .whereType<Directory>()
        .where(
          (directory) =>
              File(p.join(directory.path, 'manifest.json')).existsSync(),
        )
        .toList();

    expect(exitCode, 0);
    expect(outputDirectories, hasLength(1));
  });

  test(
    'bundle-session fails validation when session-json is missing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('cockpit_cli_test');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(BundleSessionCommand());
      final exitCode = await _runCommandRunner(runner, [
        'bundle-session',
        '--output-root',
        tempDir.path,
      ]);

      expect(exitCode, isNonZero);
      expect(tempDir.listSync(), isEmpty);
    },
  );
}

Future<int> _runCommandRunner(
  CommandRunner<int> runner,
  List<String> args,
) async {
  try {
    return await runner.run(args) ?? 0;
  } on Object {
    return 1;
  }
}
