import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_run_remote_control_script_service.dart';
import '../../application/cockpit_session_reference_resolver.dart';
import '../../artifacts/task_run_bundle_writer.dart';
import '../../recording/cockpit_recording_strategy_resolver.dart';
import '../../remote/cockpit_android_port_forwarder.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_control_script.dart';

final class RunRemoteControlScriptCommand extends Command<int> {
  RunRemoteControlScriptCommand({
    CockpitRunRemoteControlScriptService? service,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    CockpitRecordingStrategyResolver recordingStrategyResolver =
        const CockpitRecordingStrategyResolver(),
    TaskRunBundleWriter writer = const TaskRunBundleWriter(),
  }) : _service = service ??
            CockpitRunRemoteControlScriptService(
              sessionReferenceResolver: CockpitSessionReferenceResolver(
                portForwarder: portForwarder,
              ),
              recordingStrategyResolver: recordingStrategyResolver,
              writer: writer,
            ) {
    argParser
      ..addOption('base-url', help: 'Base URL for the running app session.')
      ..addOption(
        'session-json',
        help:
            'Optional session handle JSON file emitted by launch-remote-session.',
      )
      ..addOption('script-json', help: 'Path to a JSON control script file.')
      ..addOption(
        'output-root',
        help: 'Directory where the task-run bundle should be written.',
      )
      ..addOption(
        'android-device-id',
        help: 'Optional Android device ID used to set up adb port forwarding.',
      )
      ..addOption(
        'ios-device-id',
        help: 'Optional iOS Simulator device ID used for host recording.',
      );
  }

  final CockpitRunRemoteControlScriptService _service;

  @override
  String get name => 'run-remote-control-script';

  @override
  String get description =>
      'Execute a control script against a running flutter_cockpit remote session and write a bundle.';

  @override
  Future<int> run() async {
    final scriptJsonPath = _readRequiredOption('script-json');
    final outputRoot = _readRequiredOption('output-root');
    final sessionJsonPath = argResults?['session-json'] as String?;
    final baseUrl = argResults?['base-url'] as String?;
    if ((sessionJsonPath == null || sessionJsonPath.isEmpty) &&
        (baseUrl == null || baseUrl.isEmpty)) {
      throw UsageException(
        '--base-url is required when --session-json is not provided.',
        usage,
      );
    }

    final scriptFile = File(scriptJsonPath);
    if (!scriptFile.existsSync()) {
      throw UsageException(
        'Control script file does not exist: $scriptJsonPath',
        usage,
      );
    }

    final decoded = jsonDecode(await scriptFile.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Control script JSON must decode to an object.',
      );
    }

    final script = CockpitControlScript.fromJson(decoded);
    await _service.run(
      CockpitRunRemoteControlScriptRequest(
        script: script,
        outputRoot: outputRoot,
        baseUri: baseUrl == null || baseUrl.isEmpty ? null : Uri.parse(baseUrl),
        sessionHandlePath: sessionJsonPath,
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
      ),
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
