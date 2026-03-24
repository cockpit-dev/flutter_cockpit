import 'dart:io';

import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';

Future<void> main(List<String> args) async {
  final code = await CockpitCommandRunner().run(args);
  if (code != cockpitSuccessExitCode) {
    exit(code);
  }
}
