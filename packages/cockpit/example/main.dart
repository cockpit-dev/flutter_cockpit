import 'dart:io';

import 'package:cockpit/cockpit.dart';

Future<void> main(List<String> args) async {
  final runner = CockpitCommandRunner();
  if (args.isNotEmpty) {
    exitCode = await runner.run(args);
    return;
  }

  stdout.writeln('Cockpit host tooling example');
  stdout.writeln('');
  stdout.writeln('Common AI-first commands:');
  stdout.writeln('  dart run cockpit list-targets');
  stdout.writeln(
    '  dart run cockpit launch-app --project-dir . --platform macos',
  );
  stdout.writeln('  dart run cockpit read-app --profile minimal');
  stdout.writeln('  dart run cockpit capture-screenshot --name acceptance');
  stdout.writeln('  dart run cockpit read-system-capabilities');
  stdout.writeln('  dart run cockpit serve-mcp');
  stdout.writeln('');
  stdout.writeln(
    'This example can also proxy arguments into CockpitCommandRunner:',
  );
  stdout.writeln('  dart run example/main.dart read-system-capabilities');
}
