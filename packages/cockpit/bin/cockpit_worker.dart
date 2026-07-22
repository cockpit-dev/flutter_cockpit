import 'dart:io';

import 'package:cockpit/src/worker/cockpit_worker_runtime.dart';

Future<void> main(List<String> arguments) async {
  final code = await runCockpitWorker(arguments);
  await stdout.flush();
  await stderr.flush();
  exit(code);
}
