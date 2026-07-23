import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/worker/cockpit_worker_case_completion.dart';
import 'package:cockpit/src/worker/cockpit_worker_runtime.dart';

Future<void> main(List<String> arguments) async {
  final controlPath = Platform.environment['COCKPIT_COMPLETION_CRASH_CONTROL'];
  exitCode = await runCockpitWorker(
    arguments,
    completionObserver: controlPath == null
        ? null
        : (observation) => _observe(controlPath, observation),
  );
}

void _observe(
  String controlPath,
  CockpitWorkerCaseCompletionObservation observation,
) {
  if (observation.recovering) return;
  final file = File(controlPath);
  if (!file.existsSync()) return;
  final value = jsonDecode(file.readAsStringSync());
  if (value is! Map<Object?, Object?>) return;
  final control = Map<String, Object?>.from(value);
  if (control['consumed'] == true ||
      control['idempotencyKey'] != observation.idempotencyKey ||
      control['phase'] != observation.phase.name) {
    return;
  }
  control['consumed'] = true;
  file.writeAsStringSync(jsonEncode(control), flush: true);
  if (!Process.killPid(pid, ProcessSignal.sigkill)) {
    throw StateError('Could not terminate the completion probe worker.');
  }
}
