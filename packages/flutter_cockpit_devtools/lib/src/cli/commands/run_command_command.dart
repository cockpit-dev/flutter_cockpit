import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_run_command_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitRunCommandFunction = Future<CockpitRunCommandResult> Function(
  CockpitRunCommandRequest request,
);

final class RunCommandCommand extends Command<int> {
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
    argParser
      ..addOption('command-json')
      ..addOption('command-file')
      ..addOption('snapshot-options-json')
      ..addOption('snapshot-options-file')
      ..addOption('compare-against-snapshot-ref');
  }

  final CockpitRunCommandFunction _runCommand;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-command';

  @override
  String get description =>
      'Execute one cockpit command against a running app with layered interactive results.';

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
        command: CockpitCommand.fromJson(cockpitNormalizeJsonKeys(commandJson)),
        resultProfile: cockpitReadResultProfile(argResults),
        snapshotOptions: snapshotOptionsJson == null
            ? null
            : CockpitSnapshotOptions.fromJson(
                cockpitNormalizeJsonKeys(snapshotOptionsJson),
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
