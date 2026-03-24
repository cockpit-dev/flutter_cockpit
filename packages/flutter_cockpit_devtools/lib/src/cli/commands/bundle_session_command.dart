import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../artifacts/task_run_bundle_writer.dart';
import '../cockpit_command_runner.dart';

final class BundleSessionCommand extends Command<int> {
  BundleSessionCommand({
    TaskRunBundleWriter writer = const TaskRunBundleWriter(),
  }) : _writer = writer {
    argParser
      ..addOption(
        'session-json',
        help: 'Path to an exported CockpitContextBundle JSON file.',
      )
      ..addOption(
        'output-root',
        help: 'Directory where the task-run bundle should be written.',
      );
  }

  final TaskRunBundleWriter _writer;

  @override
  String get name => 'bundle-session';

  @override
  String get description =>
      'Write a standard task-run bundle from session JSON.';

  @override
  Future<int> run() async {
    final sessionJsonPath = _readRequiredOption('session-json');
    final outputRoot = _readRequiredOption('output-root');
    final sessionFile = File(sessionJsonPath);

    if (!sessionFile.existsSync()) {
      throw UsageException(
        'Session JSON file does not exist: $sessionJsonPath',
        usage,
      );
    }

    final decoded = jsonDecode(await sessionFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Session JSON must decode to an object.');
    }

    final bundle = CockpitContextBundle.fromJson(decoded);
    await _writer.writeBundle(bundle: bundle, outputRoot: outputRoot);

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
