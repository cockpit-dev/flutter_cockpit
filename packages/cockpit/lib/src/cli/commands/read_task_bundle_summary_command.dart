import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_read_task_bundle_summary_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadTaskBundleSummaryFunction =
    Future<CockpitReadTaskBundleSummaryResult> Function(
      CockpitReadTaskBundleSummaryRequest request,
    );

final class ReadTaskBundleSummaryCommand extends CockpitCliCommand {
  ReadTaskBundleSummaryCommand({
    CockpitReadTaskBundleSummaryService? service,
    CockpitReadTaskBundleSummaryFunction? readSummary,
    StringSink? stdoutSink,
  }) : _readSummary =
           readSummary ??
           (service ?? const CockpitReadTaskBundleSummaryService()).read,
       _stdoutSink = stdoutSink ?? stdout {
    argParser.addOption(
      'bundle-dir',
      help: 'Path to a flutter_cockpit task-run bundle directory.',
    );
  }

  final CockpitReadTaskBundleSummaryFunction _readSummary;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-task-bundle-summary';

  @override
  String get description =>
      'Read a task-run bundle and emit the compact delivery summary used by AI agents.';

  @override
  String get summary => 'Read bundle delivery evidence.';

  @override
  String get category => CockpitCliCategory.delivery;

  @override
  String get helpWhen =>
      'Use after run-script, run-task, or validate-task when the next step needs bundle evidence without opening raw steps, snapshots, screenshots, or recordings.';

  @override
  String get helpNeeds => 'A task-run bundle directory.';

  @override
  String get helpExample =>
      'cockpit read-task-bundle-summary --bundle-dir /tmp/flutter_cockpit/out/session_1';

  @override
  String get helpWrites =>
      'A compact AI-readable summary by default, or lower camel case JSON with --stdout-format json.';

  @override
  Future<int> run() async {
    final bundleDir = _readRequiredOption('bundle-dir');
    final directory = Directory(bundleDir);
    if (!directory.existsSync()) {
      throw UsageException(
        'Bundle directory does not exist: $bundleDir',
        usage,
      );
    }

    final result = await _readSummary(
      CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir),
    );
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
