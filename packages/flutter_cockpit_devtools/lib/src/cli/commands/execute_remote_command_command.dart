import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_execute_remote_command_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitExecuteRemoteCommandFunction
    = Future<CockpitExecuteRemoteCommandResult> Function(
  CockpitExecuteRemoteCommandRequest request,
);

final class ExecuteRemoteCommandCommand extends Command<int> {
  ExecuteRemoteCommandCommand({
    CockpitExecuteRemoteCommandService? service,
    CockpitExecuteRemoteCommandFunction? execute,
    StringSink? stdoutSink,
  })  : _execute = execute ??
            (service ?? CockpitExecuteRemoteCommandService()).execute,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    cockpitAddProfileArg(argParser);
    argParser
      ..addOption('command-json')
      ..addOption('command-file')
      ..addOption('snapshot-options-json')
      ..addOption('snapshot-options-file')
      ..addOption('compare-against-snapshot-ref');
  }

  final CockpitExecuteRemoteCommandFunction _execute;
  final StringSink _stdoutSink;

  @override
  String get name => 'execute-remote-command';

  @override
  String get description =>
      'Execute one flutter_cockpit command against a live remote session with layered interactive results.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
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
    final result = await _execute(
      CockpitExecuteRemoteCommandRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: argResults?['session-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
        command: CockpitCommand.fromJson(commandJson),
        resultProfile: cockpitReadResultProfile(argResults),
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
