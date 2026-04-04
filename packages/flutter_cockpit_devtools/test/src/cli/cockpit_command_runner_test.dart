import 'dart:io';

import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('runner registers workspace intelligence commands', () {
    final commands = CockpitCommandRunner().commands.keys.toSet();

    expect(
      commands,
      containsAll(<String>[
        'pub-dev-search',
        'pub',
        'read-package-uris',
        'grep-package-uris',
        'lsp',
        'analyze-files',
        'create-project',
        'analyze-workspace',
        'format-workspace',
        'run-tests',
        'apply-fixes',
      ]),
    );
  });

  test('usage errors are written to stderr', () async {
    final stderrBuffer = StringBuffer();
    final exitCode = await CockpitCommandRunner(
      stderrSink: stderrBuffer,
    ).run(<String>['launch-app']);

    expect(exitCode, cockpitUsageExitCode);
    expect(stderrBuffer.toString(), contains('--project-dir is required.'));
    expect(stderrBuffer.toString(),
        contains('Usage: flutter_cockpit_devtools launch-app'));
  });

  test('data errors are written to stderr', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_runner_stderr',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final configFile = File(p.join(tempDir.path, 'invalid.json'));
    await configFile.writeAsString('[]');

    final stderrBuffer = StringBuffer();
    final exitCode = await CockpitCommandRunner(
      stderrSink: stderrBuffer,
    ).run(<String>['run-task', '--config-json', configFile.path]);

    expect(exitCode, cockpitDataExitCode);
    expect(
      stderrBuffer.toString(),
      contains('Run task config JSON must decode to an object.'),
    );
  });
}
