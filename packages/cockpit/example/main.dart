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
  stdout.writeln('Cockpit 2.0 resource commands:');
  stdout.writeln('  dart run cockpit daemon status');
  stdout.writeln('  dart run cockpit root list');
  stdout.writeln('  dart run cockpit workspace list');
  stdout.writeln('  dart run cockpit operation list');
  stdout.writeln('  dart run cockpit case list');
  stdout.writeln('  dart run cockpit_mcp');
  stdout.writeln('');
  stdout.writeln(
    'This example can also proxy arguments into CockpitCommandRunner:',
  );
  stdout.writeln('  dart run example/main.dart daemon status');
}
