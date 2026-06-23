import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_application_service_exception.dart';
import '../../application/cockpit_run_remote_control_script_service.dart';
import '../../application/cockpit_session_reference_resolver.dart';
import '../../artifacts/task_run_bundle_writer.dart';
import '../../recording/cockpit_recording_strategy_resolver.dart';
import '../../remote/cockpit_android_port_forwarder.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_control_script.dart';
import '../cockpit_interactive_cli_support.dart';
import '../cockpit_run_script_cli_payload.dart';

typedef CockpitRunRemoteControlScriptCommandFunction =
    Future<CockpitRunRemoteControlScriptResult> Function(
      CockpitRunRemoteControlScriptRequest request,
    );

final class RunRemoteControlScriptCommand extends CockpitCliCommand {
  RunRemoteControlScriptCommand({
    CockpitRunRemoteControlScriptService? service,
    CockpitRunRemoteControlScriptCommandFunction? runScript,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    CockpitRecordingStrategyResolver recordingStrategyResolver =
        const CockpitRecordingStrategyResolver(),
    TaskRunBundleWriter writer = const TaskRunBundleWriter(),
    StringSink? stdoutSink,
  }) : _runScript =
           runScript ??
           (service ??
                   CockpitRunRemoteControlScriptService(
                     sessionReferenceResolver: CockpitSessionReferenceResolver(
                       portForwarder: portForwarder,
                     ),
                     recordingStrategyResolver: recordingStrategyResolver,
                     writer: writer,
                   ))
               .run,
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('base-url', help: 'Base URL for the running app session.')
      ..addOption('session-json', help: cockpitRemoteSessionJsonOptionHelp)
      ..addOption('script', help: 'Path to a JSON or YAML control script file.')
      ..addOption(
        'script-json',
        help: 'Deprecated alias for --script. Accepts JSON or YAML.',
      )
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
    cockpitAddOutputArgs(argParser);
  }

  final CockpitRunRemoteControlScriptCommandFunction _runScript;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-remote-control-script';

  @override
  String get description =>
      'Execute a control script against a running flutter_cockpit remote session and write a bundle.';

  @override
  String get summary => 'Run remote script bundle.';

  @override
  String get category => CockpitCliCategory.delivery;

  @override
  String get helpWhen =>
      'Use for legacy direct remote sessions when run-script app handles are unavailable.';

  @override
  String get helpNeeds =>
      'A remote session reference from --session-json, the default latest remote session handle, or --base-url; plus a control script file and output bundle directory.';

  @override
  String get helpExample =>
      'cockpit run-remote-control-script --script /tmp/script.yaml --output-root /tmp/bundle';

  @override
  String get helpWrites =>
      'A task-run bundle under --output-root. The command exits non-zero when the bundle status is failed; prefer run-script for app-first workflows.';

  @override
  Future<int> run() async {
    final scriptPath = _readRequiredScriptPath();
    final outputRoot = _readRequiredOption('output-root');
    final sessionJsonPath = cockpitResolveRemoteSessionHandlePath(argResults);
    final baseUrl = argResults?['base-url'] as String?;
    if ((sessionJsonPath == null || sessionJsonPath.isEmpty) &&
        (baseUrl == null || baseUrl.isEmpty)) {
      throw UsageException(
        '--base-url is required when --session-json is not provided and '
        '${cockpitDefaultRemoteSessionHandlePath()} does not exist.',
        usage,
      );
    }

    final scriptFile = File(scriptPath);
    if (!scriptFile.existsSync()) {
      throw UsageException(
        'Control script file does not exist: $scriptPath',
        usage,
      );
    }

    final scriptText = await scriptFile.readAsString();
    final script = cockpitDecodeCliJson(
      decode: () => cockpitControlScriptFromText(scriptText),
      label: 'script',
      usage: usage,
    );
    final result = await _runScript(
      CockpitRunRemoteControlScriptRequest(
        script: script,
        outputRoot: outputRoot,
        baseUri: baseUrl == null || baseUrl.isEmpty ? null : Uri.parse(baseUrl),
        sessionHandlePath: sessionJsonPath,
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
      ),
    );
    if (result.manifest.status == CockpitTaskStatus.failed) {
      final summary = result.manifest.failureSummary ?? 'Unknown failure.';
      throw CockpitApplicationServiceException(
        code: 'controlScriptFailed',
        message:
            'Control script bundle failed: $summary See ${result.bundleDir.path}.',
        details: cockpitRunScriptFailureDetails(
          result: result,
          outputRoot: outputRoot,
        ),
      );
    }
    await cockpitWriteJsonPayload(
      commandName: name,
      payload: cockpitRunScriptResultPayload(
        commandName: name,
        result: result,
        outputRoot: outputRoot,
      ),
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

  String _readRequiredScriptPath() {
    final script = argResults?['script'] as String?;
    if (script != null && script.isNotEmpty) {
      return script;
    }
    final legacy = argResults?['script-json'] as String?;
    if (legacy != null && legacy.isNotEmpty) {
      return legacy;
    }
    throw UsageException('--script is required.', usage);
  }
}
