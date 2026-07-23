import 'dart:io';

import 'package:cockpit/src/supervisor/cockpit_daemon_runtime.dart';

Future<void> main(List<String> arguments) async {
  var code = 1;
  try {
    code = await runCockpitDaemon(arguments);
  } on Object catch (error) {
    stderr.writeln('cockpitd failed: $error');
  }
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
