import 'dart:io';
import 'dart:convert';

import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../application/cockpit_execute_remote_command_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitExecuteRemoteCommandFunction =
    Future<CockpitExecuteRemoteCommandResult> Function(
      CockpitExecuteRemoteCommandRequest request,
    );

final class ExecuteRemoteCommandCommand extends CockpitCliCommand {
  ExecuteRemoteCommandCommand({
    CockpitExecuteRemoteCommandService? service,
    CockpitExecuteRemoteCommandFunction? execute,
    StringSink? stdoutSink,
  }) : _execute =
           execute ?? (service ?? CockpitExecuteRemoteCommandService()).execute,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    cockpitAddProfileArg(argParser);
    argParser
      ..addOption('command-json', help: 'Inline JSON object for one command.')
      ..addOption('command-file', help: 'Path to one command JSON object.')
      ..addOption(
        'snapshot-options-json',
        help: 'Inline JSON that overrides post-command snapshot detail.',
      )
      ..addOption(
        'snapshot-options-file',
        help: 'Path to post-command snapshot options JSON.',
      )
      ..addOption(
        'compare-against-snapshot-ref',
        help: 'Existing snapshot ref used to compute a bounded delta.',
      );
  }

  final CockpitExecuteRemoteCommandFunction _execute;
  final StringSink _stdoutSink;

  @override
  String get name => 'execute-remote-command';

  @override
  String get description =>
      'Execute one flutter_cockpit command against a live remote session with layered interactive results.';

  @override
  String get summary => 'Run one remote command.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use for direct remote sessions; prefer run-command for app-first handles.';

  @override
  String get helpNeeds =>
      'A remote session reference and one command JSON object.';

  @override
  String get helpExample =>
      'cockpit execute-remote-command --session-json /tmp/session.json --command-file /tmp/command.json --profile standard';

  @override
  String get helpWrites =>
      'Layered command result JSON with post-action state, artifacts, and optional deltas.';

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
        sessionHandlePath: cockpitResolveRemoteSessionHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
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
