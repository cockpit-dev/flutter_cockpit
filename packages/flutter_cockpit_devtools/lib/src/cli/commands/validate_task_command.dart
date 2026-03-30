import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_validate_task_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

final class ValidateTaskCommand extends Command<int> {
  ValidateTaskCommand({
    CockpitValidateTaskService? service,
    StringSink? stdoutSink,
  })  : _service = service ?? CockpitValidateTaskService(),
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'config-json',
        help: 'Path to a JSON validate-task configuration file.',
      )
      ..addOption(
        'output-json',
        help:
            'Optional file path where the validate-task result JSON should be written.',
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
        'Validate task config JSON must decode to an object.',
      );
    }

    final request = CockpitValidateTaskRequest.fromJson(
      Map<String, Object?>.from(decoded),
    );
    final result = await _service.validate(request);
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
