import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_cockpit_devtools/src/cli/cockpit_interactive_cli_support.dart';
import 'package:test/test.dart';

void main() {
  test(
    'cockpitResolveAppHandlePath ignores the implicit default handle when base-url is explicitly provided',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_cli_support_base_url_precedence',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final defaultHandle = File(cockpitDefaultAppHandlePath(tempDir.path));
      await defaultHandle.parent.create(recursive: true);
      await defaultHandle.writeAsString('{}');

      final parser = ArgParser()
        ..addOption('app-json')
        ..addOption('base-url');
      final argResults = parser.parse(<String>[
        '--base-url',
        'http://127.0.0.1:47331',
      ]);

      expect(
        cockpitResolveAppHandlePath(
          argResults,
          workingDirectory: tempDir.path,
        ),
        isNull,
      );
    },
  );

  test(
    'cockpitResolveAppHandlePath does not assume every command defines base-url',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_cli_support_no_base_url_option',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final defaultHandle = File(cockpitDefaultAppHandlePath(tempDir.path));
      await defaultHandle.parent.create(recursive: true);
      await defaultHandle.writeAsString('{}');

      final parser = ArgParser()..addOption('app-json');
      final argResults = parser.parse(const <String>[]);

      expect(
        cockpitResolveAppHandlePath(
          argResults,
          workingDirectory: tempDir.path,
        ),
        defaultHandle.path,
      );
    },
  );
}
