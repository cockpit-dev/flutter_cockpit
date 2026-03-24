import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../adapters/cockpit_automation_adapter.dart';
import '../../adapters/cockpit_capture_adapter.dart';
import '../../artifacts/task_run_bundle_writer.dart';
import '../../runner/cockpit_control_runner.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_control_script.dart';

final class RunControlScriptCommand extends Command<int> {
  RunControlScriptCommand({
    CockpitAutomationAdapter? automationAdapter,
    CockpitCaptureAdapter? captureAdapter,
    TaskRunBundleWriter writer = const TaskRunBundleWriter(),
  })  : _automationAdapter = automationAdapter,
        _captureAdapter = captureAdapter,
        _writer = writer {
    argParser
      ..addOption('script-json', help: 'Path to a JSON control script file.')
      ..addOption(
        'output-root',
        help: 'Directory where the task-run bundle should be written.',
      );
  }

  final CockpitAutomationAdapter? _automationAdapter;
  final CockpitCaptureAdapter? _captureAdapter;
  final TaskRunBundleWriter _writer;

  @override
  String get name => 'run-control-script';

  @override
  String get description =>
      'Execute a JSON control script and write the resulting task-run bundle.';

  @override
  Future<int> run() async {
    final scriptJsonPath = _readRequiredOption('script-json');
    final outputRoot = _readRequiredOption('output-root');
    final scriptFile = File(scriptJsonPath);

    if (!scriptFile.existsSync()) {
      throw UsageException(
        'Control script file does not exist: $scriptJsonPath',
        usage,
      );
    }

    final automationAdapter = _automationAdapter;
    if (automationAdapter == null) {
      throw const FormatException(
        'No automation adapter is configured for run-control-script.',
      );
    }

    final decoded = jsonDecode(await scriptFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Control script JSON must decode to an object.',
      );
    }

    final script = CockpitControlScript.fromJson(decoded);
    final environment = script.environment;
    if (environment == null) {
      throw const FormatException(
        'run-control-script requires an explicit environment because it does not execute through a remote session.',
      );
    }
    final runner = CockpitControlRunner(
      automationAdapter: automationAdapter,
      captureAdapter: _captureAdapter,
      sessionController: CockpitSessionController(
        sessionId: script.sessionId,
        taskId: script.taskId,
        platform: script.platform,
      ),
      failFast: script.failFast,
    );
    final runResult = await runner.run(
      environment: environment,
      commands: script.commands,
    );

    await _writer.writeBundle(
      bundle: runResult.bundle,
      outputRoot: outputRoot,
      artifactPayloads: runResult.artifactPayloads,
      artifactSourcePaths: runResult.artifactSourcePaths,
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
