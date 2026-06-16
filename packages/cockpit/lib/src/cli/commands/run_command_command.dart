import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_run_command_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitRunCommandFunction =
    Future<CockpitRunCommandResult> Function(CockpitRunCommandRequest request);

final class RunCommandCommand extends CockpitCliCommand {
  RunCommandCommand({
    CockpitRunCommandService? service,
    CockpitRunCommandFunction? runCommand,
    StringSink? stdoutSink,
  }) : _runCommand = runCommand ?? (service ?? CockpitRunCommandService()).run,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    cockpitAddProfileArg(
      argParser,
      defaultProfile: CockpitInteractiveResultProfileName.standard,
    );
    cockpitAddCommandJsonArgs(argParser);
    cockpitAddCommandTimeoutArg(argParser);
    cockpitAddSnapshotOptionsArgs(argParser);
    cockpitAddCompareAgainstSnapshotRefArg(argParser);
  }

  final CockpitRunCommandFunction _runCommand;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-command';

  @override
  String get description =>
      'Execute one cockpit command against a running app with layered results.';

  @override
  String get summary => 'Run one command against the app.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Drive one UI or assertion step, then immediately inspect the result and choose the next move.';

  @override
  String get helpNeeds =>
      'An app reference plus one command JSON object from --command-json or --command-file. Prefer --command-file once the payload stops being trivial.';

  @override
  String get helpShape =>
      'command.json = {"commandId":"tap-save","commandType":"tap","locator":{"text":"Save"}}; safe first commandType values: tap, enterText, assertText, waitForUiIdle, scrollUntilVisible, captureScreenshot. Start locators with text, semanticId, tooltip, type, ancestor, index, or fallbacks; use key only when the app already exposes a stable key.';

  @override
  String get helpExample =>
      'cockpit run-command --app-json /tmp/app.json --command-file /tmp/command.json --profile standard';

  @override
  String get helpWrites =>
      'Command outcome, optional UI and diagnostics layers, and maybe snapshotRef. Re-read state after non-trivial actions; command success alone is not proof.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final commandJson = await cockpitReadRequiredJsonObject(
      argResults: argResults,
      inlineOption: 'command-json',
      fileOption: 'command-file',
      label: 'command JSON',
      usage: usage,
    );
    final snapshotOptionsJson = await cockpitReadOptionalJsonObject(
      argResults: argResults,
      inlineOption: 'snapshot-options-json',
      fileOption: 'snapshot-options-file',
      label: 'snapshot options JSON',
      usage: usage,
    );
    final result = await _runCommand(
      CockpitRunCommandRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
        command: cockpitDecodeCliJson(
          decode: () => CockpitCommand.fromJson(commandJson),
          label: 'command JSON',
          usage: usage,
        ),
        resultProfile: cockpitReadResultProfile(argResults),
        defaultCommandTimeout: Duration(
          milliseconds:
              cockpitReadOptionalPositiveInt(argResults, 'timeout-ms', usage) ??
              30000,
        ),
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : cockpitDecodeCliJson(
                decode: () =>
                    CockpitSnapshotOptions.fromJson(snapshotOptionsJson),
                label: 'snapshot options JSON',
                usage: usage,
              ),
        compareAgainstSnapshotRef:
            argResults?['compare-against-snapshot-ref'] as String?,
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
