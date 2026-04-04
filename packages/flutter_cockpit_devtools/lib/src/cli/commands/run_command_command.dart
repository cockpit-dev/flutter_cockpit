import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_run_command_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitRunCommandFunction = Future<CockpitRunCommandResult> Function(
  CockpitRunCommandRequest request,
);

final class RunCommandCommand extends CockpitCliCommand {
  RunCommandCommand({
    CockpitRunCommandService? service,
    CockpitRunCommandFunction? runCommand,
    StringSink? stdoutSink,
  })  : _runCommand = runCommand ?? (service ?? CockpitRunCommandService()).run,
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
      'An app reference plus one command JSON object from --command-json or --command-file.';

  @override
  String get helpShape =>
      'command.json = {"commandId":"open-today","commandType":"tap","locator":{"text":"Today","key":"nav-today","ancestor":{"route":"/inbox"}},"parameters":{"hitTestMissPolicy":"warn"}}; locator can combine text/key/semanticId/type/path and nested ancestor filters; optional --timeout-ms sets a default for commands that omit timeoutMs.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-command --app-json /tmp/app.json --command-file /tmp/command.json --profile standard';

  @override
  String get helpWrites =>
      'Command outcome, optional UI and diagnostics layers, and maybe snapshotRef.';

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
        appHandlePath: argResults?['app-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
        command: CockpitCommand.fromJson(commandJson),
        resultProfile: cockpitReadResultProfile(argResults),
        defaultCommandTimeout: Duration(
          milliseconds:
              cockpitReadOptionalInt(argResults, 'timeout-ms') ?? 4000,
        ),
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : CockpitSnapshotOptions.fromJson(snapshotOptionsJson),
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
