import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_app_reference_resolver.dart';
import '../../application/cockpit_run_remote_control_script_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_control_script.dart';
import '../cockpit_interactive_cli_support.dart';

final class RunScriptCommand extends Command<int> {
  RunScriptCommand({
    CockpitRunRemoteControlScriptService? service,
    CockpitAppReferenceResolver? appReferenceResolver,
  })  : _service = service ?? CockpitRunRemoteControlScriptService(),
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

  final CockpitRunRemoteControlScriptService _service;
  final CockpitAppReferenceResolver _appReferenceResolver;

  @override
  String get name => 'run-script';

  @override
  String get description =>
      'Execute a control script against a running app and write a bundle.';

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
      appHandlePath: argResults?['app-json'] as String?,
      baseUri: cockpitReadOptionalBaseUri(argResults),
      androidDeviceId: argResults?['android-device-id'] as String?,
    );
    final script = CockpitControlScript.fromJson(decoded);
    await _service.run(
      CockpitRunRemoteControlScriptRequest(
        script: script,
        outputRoot: outputRoot,
        platformAppId: resolved.app?.platformAppId ??
            resolved.developmentRecord?.handle.remoteSessionHandle?.appId ??
            resolved.remoteRecord?.handle.appId,
        baseUri: resolved.baseUri,
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
        portForwardingHandled: true,
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
