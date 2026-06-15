import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_run_task_service.dart';
import '../cockpit_cli_config_file.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

final class RunTaskCommand extends CockpitCliCommand {
  RunTaskCommand({CockpitRunTaskService? service, StringSink? stdoutSink})
    : _service = service ?? CockpitRunTaskService(),
      _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'config',
        help: 'Path to a JSON or YAML run-task configuration file.',
      )
      ..addOption(
        'config-json',
        help: 'Deprecated alias for --config. Accepts JSON or YAML.',
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
      'A run-task config file that describes launch, script, outputRoot, and any evidence requirements.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-task --config /tmp/run_task.yaml';

  @override
  String get helpWrites =>
      'A structured result with classification, recommendedNextStep, and bundleSummary. Default stdout includes compact AI-readable issues and bundle sections; add --stdout-format json only for jq pipelines.';

  @override
  Future<int> run() async {
    final configPath = _readRequiredConfigPath();

    final request = CockpitRunTaskRequest.fromJson(
      cockpitReadConfigFile(
        path: configPath,
        label: 'Run task config',
        usage: usage,
      ),
    );
    final result = await _service.run(request);
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );

    return cockpitSuccessExitCode;
  }

  String _readRequiredConfigPath() {
    final config = argResults?['config'] as String?;
    if (config != null && config.isNotEmpty) {
      return config;
    }
    final legacy = argResults?['config-json'] as String?;
    if (legacy != null && legacy.isNotEmpty) {
      return legacy;
    }
    throw UsageException('--config is required.', usage);
  }
}
