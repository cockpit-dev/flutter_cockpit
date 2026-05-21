import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_app_reference_resolver.dart';
import '../../application/cockpit_application_service_exception.dart';
import '../../application/cockpit_run_remote_control_script_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_control_script.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitRunScriptFunction = Future<CockpitRunRemoteControlScriptResult>
    Function(
  CockpitRunRemoteControlScriptRequest request,
);

final class RunScriptCommand extends CockpitCliCommand {
  RunScriptCommand({
    CockpitRunRemoteControlScriptService? service,
    CockpitRunScriptFunction? runScript,
    CockpitAppReferenceResolver? appReferenceResolver,
  })  : _runScript = runScript ??
            (service ?? CockpitRunRemoteControlScriptService()).run,
        _appReferenceResolver =
            appReferenceResolver ?? CockpitAppReferenceResolver() {
    cockpitAddAppArgs(argParser);
    argParser
      ..addOption('script-json', help: 'Path to a JSON control script file.')
      ..addOption(
        'output-root',
        help: 'Directory where the task-run bundle should be written.',
      )
      ..addOption(
        'ios-device-id',
        help: 'Optional iOS Simulator device ID used for host recording.',
      );
  }

  final CockpitRunScriptFunction _runScript;
  final CockpitAppReferenceResolver _appReferenceResolver;

  @override
  String get name => 'run-script';

  @override
  String get description =>
      'Execute a control script against a running app and write a bundle.';

  @override
  String get summary => 'Run a script and write a bundle.';

  @override
  String get category => CockpitCliCategory.delivery;

  @override
  String get helpWhen =>
      'Use when you already know the whole scripted flow and want a delivery-grade bundle from a running app.';

  @override
  String get helpNeeds =>
      'An app reference, a control script JSON file, and an output directory for the bundle.';

  @override
  String get helpShape =>
      'script.json is a task-style control script object with sessionId, task_id, commands, and optional recording settings.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-script --app-json /tmp/app.json --script-json /tmp/script.json --output-root /tmp/bundle';

  @override
  String get helpWrites =>
      'A task-run bundle under --output-root. The command exits non-zero when the bundle status is failed.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final scriptJsonPath = _readRequiredOption('script-json');
    final outputRoot = _readRequiredOption('output-root');

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
    final resolved = await _appReferenceResolver.resolve(
      appHandlePath: cockpitResolveAppHandlePath(argResults),
      baseUri: cockpitReadOptionalBaseUri(argResults),
      androidDeviceId: argResults?['android-device-id'] as String?,
    );
    final script = cockpitDecodeCliJson(
      decode: () => CockpitControlScript.fromJson(decoded),
      label: 'script JSON',
      usage: usage,
    );
    final result = await _runScript(
      CockpitRunRemoteControlScriptRequest(
        script: script,
        outputRoot: outputRoot,
        platformAppId: resolved.app?.platformAppId ??
            resolved.developmentRecord?.handle.remoteSessionHandle
                ?.effectivePlatformAppId ??
            resolved.remoteRecord?.handle.effectivePlatformAppId,
        processId: resolved.app?.processId ??
            resolved.developmentRecord?.handle.remoteSessionHandle?.processId ??
            resolved.remoteRecord?.handle.processId,
        baseUri: resolved.baseUri,
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
        portForwardingHandled: true,
      ),
    );
    if (result.manifest.status == CockpitTaskStatus.failed) {
      final summary = result.manifest.failureSummary ?? 'Unknown failure.';
      throw CockpitApplicationServiceException(
        code: 'controlScriptFailed',
        message:
            'Control script bundle failed: $summary See ${result.bundleDir.path}.',
      );
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
