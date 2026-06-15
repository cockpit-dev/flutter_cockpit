import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_validate_task_service.dart';
import '../cockpit_cli_config_file.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

final class ValidateTaskCommand extends CockpitCliCommand {
  ValidateTaskCommand({
    CockpitValidateTaskService? service,
    StringSink? stdoutSink,
  }) : _service = service ?? CockpitValidateTaskService(),
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'config',
        help: 'Path to a JSON or YAML validate-task configuration file.',
      )
      ..addOption(
        'config-json',
        help: 'Deprecated alias for --config. Accepts JSON or YAML.',
      );
  }

  final CockpitValidateTaskService _service;
  final StringSink _stdoutSink;

  @override
  String get name => 'validate-task';

  @override
  String get description =>
      'Run a full flutter_cockpit task workflow and validate the persisted bundle as a delivery-ready artifact set.';

  @override
  String get summary => 'Run task and validate delivery gates.';

  @override
  String get category => CockpitCliCategory.delivery;

  @override
  String get helpWhen =>
      'Use when the output must be delivery-ready, not just executed. This is the strictest one-shot command.';

  @override
  String get helpNeeds =>
      'A validate-task config file with the same launch and script inputs as run-task plus validation requirements.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools validate-task --config /tmp/validate_task.yaml';

  @override
  String get helpWrites =>
      'A structured result with run_task output, validation status, failures, and delivery guidance. Default stdout includes compact AI-readable issues and bundle sections; add --stdout-format json only for jq pipelines.';

  @override
  Future<int> run() async {
    final configPath = _readRequiredConfigPath();

    final request = CockpitValidateTaskRequest.fromJson(
      cockpitReadConfigFile(
        path: configPath,
        label: 'Validate task config',
        usage: usage,
      ),
    );
    final result = await _service.validate(request);
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
