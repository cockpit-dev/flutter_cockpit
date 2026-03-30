import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_run_task_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

final class RunTaskCommand extends CockpitCliCommand {
  RunTaskCommand({CockpitRunTaskService? service, StringSink? stdoutSink})
      : _service = service ?? CockpitRunTaskService(),
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'config-json',
        help: 'Path to a JSON run-task configuration file.',
      )
      ..addOption(
        'output-json',
        help:
            'Optional file path where the run-task result JSON should be written.',
      );
  }

  final CockpitRunTaskService _service;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-task';

  @override
  String get description =>
      'Run a full flutter_cockpit task workflow including bootstrap, baseline, execution, summary reads, and classification.';

  @override
  String get summary => 'Launch, drive, classify, and summarize.';

  @override
  String get category => CockpitCliCategory.delivery;

  @override
  String get helpWhen =>
      'Use for one-shot end-to-end execution when the workflow should launch, drive, and classify a task in one call.';

  @override
  String get helpNeeds =>
      'A run-task config JSON file that describes launch, script, output_root, and any evidence requirements.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-task --config-json /tmp/run_task.json --output-json /tmp/run_task_result.json';

  @override
  String get helpWrites =>
      'A structured result with classification, recommended_next_step, and bundle_summary.';

  @override
  Future<int> run() async {
    final configPath = _readRequiredOption('config-json');
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      throw UsageException(
        'Config JSON file does not exist: $configPath',
        usage,
      );
    }

    final decoded = jsonDecode(await configFile.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException(
        'Run task config JSON must decode to an object.',
      );
    }

    final request = CockpitRunTaskRequest.fromJson(
      Map<String, Object?>.from(decoded),
    );
    final result = await _service.run(request);
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );

    return cockpitSuccessExitCode;
  }

  String _readRequiredOption(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      throw UsageException('--$name is required.', usage);
    }
    return value;
  }
}
