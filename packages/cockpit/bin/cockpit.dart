import 'dart:io';

import 'package:cockpit/cockpit.dart';

Future<void> main(List<String> args) async {
  final code = await CockpitCommandRunner().run(args);
  if (code != cockpitSuccessExitCode) {
    exit(code);
  }
}
