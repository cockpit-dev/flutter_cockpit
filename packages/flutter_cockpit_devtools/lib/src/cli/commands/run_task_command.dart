import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_run_task_service.dart';
import '../cockpit_command_runner.dart';

final class RunTaskCommand extends Command<int> {
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
    final payload = const JsonEncoder.withIndent('  ').convert(result.toJson());
    final outputJson = argResults?['output-json'] as String?;

    if (outputJson == null || outputJson.isEmpty) {
      _stdoutSink.writeln(payload);
    } else {
      final outputFile = File(outputJson);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsString(payload);
    }

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
