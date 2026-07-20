import 'dart:io';
import 'dart:convert';

import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../application/cockpit_execute_remote_command_batch_service.dart';
import '../../application/cockpit_interactive_result_profile.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitExecuteRemoteCommandBatchFunction =
    Future<CockpitExecuteRemoteCommandBatchResult> Function(
      CockpitExecuteRemoteCommandBatchRequest request,
    );

final class ExecuteRemoteCommandBatchCommand extends CockpitCliCommand {
  ExecuteRemoteCommandBatchCommand({
    CockpitExecuteRemoteCommandBatchService? service,
    CockpitExecuteRemoteCommandBatchFunction? execute,
    StringSink? stdoutSink,
  }) : _execute =
           execute ??
           (service ?? CockpitExecuteRemoteCommandBatchService()).execute,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    cockpitAddProfileArg(argParser, optionName: 'default-profile');
    argParser
      ..addOption(
        'commands-json',
        help: 'Inline JSON array of command objects.',
      )
      ..addOption('commands-file', help: 'Path to a JSON command array.')
      ..addFlag(
        'fail-fast',
        defaultsTo: true,
        negatable: true,
        help: 'Stop the batch after the first failed command.',
      )
      ..addOption(
        'recording-json',
        help: 'Inline recording request JSON for the whole batch.',
      )
      ..addOption(
        'recording-file',
        help: 'Path to recording request JSON for the whole batch.',
      )
      ..addOption(
        'final-snapshot-profile',
        allowed: CockpitInteractiveResultProfileName.values
            .map((profile) => profile.jsonValue)
            .toList(growable: false),
        help: 'Profile for the final post-batch snapshot.',
      )
      ..addOption(
        'final-snapshot-options-json',
        help: 'Inline JSON that overrides final snapshot detail.',
      )
      ..addOption(
        'final-snapshot-options-file',
        help: 'Path to final snapshot options JSON.',
      );
  }

  final CockpitExecuteRemoteCommandBatchFunction _execute;
  final StringSink _stdoutSink;

  @override
  String get name => 'execute-remote-command-batch';

  @override
  String get description =>
      'Execute multiple flutter_cockpit commands in order against a live remote session.';

  @override
  String get summary => 'Run remote command batch.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use for short ordered remote flows where one round-trip per command would waste tokens.';

  @override
  String get helpNeeds =>
      'A remote session reference and a bounded JSON array of command objects.';

  @override
  String get helpExample =>
      'cockpit execute-remote-command-batch --session-json /tmp/session.json --commands-file /tmp/commands.json --default-profile minimal --final-snapshot-profile standard';

  @override
  String get helpWrites =>
      'Layered batch result JSON with per-step summaries, final state, and optional recording metadata.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final commandItems = await cockpitReadRequiredJsonObjectList(
      argResults: argResults,
      inlineOption: 'commands-json',
      fileOption: 'commands-file',
      label: 'commands JSON',
      usage: usage,
    );
    final recordingJson = await cockpitReadOptionalJsonObject(
      argResults: argResults,
      inlineOption: 'recording-json',
      fileOption: 'recording-file',
      label: 'recording JSON',
      usage: usage,
    );
    final finalSnapshotOptionsJson = await cockpitReadOptionalJsonObject(
      argResults: argResults,
      inlineOption: 'final-snapshot-options-json',
      fileOption: 'final-snapshot-options-file',
      label: 'final snapshot options JSON',
      usage: usage,
    );
    final result = await _execute(
      CockpitExecuteRemoteCommandBatchRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: cockpitResolveRemoteSessionHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
        defaultResultProfile: cockpitReadResultProfile(
          argResults,
          optionName: 'default-profile',
        ),
        commands: commandItems.map(_readBatchCommand).toList(growable: false),
        failFast: argResults?['fail-fast'] as bool? ?? true,
        recording: recordingJson == null
            ? null
            : CockpitRecordingRequest.fromJson(recordingJson),
        finalSnapshotProfile: _readOptionalProfile(
          argResults?['final-snapshot-profile'],
        ),
        finalSnapshotOptions: finalSnapshotOptionsJson == null
            ? null
            : CockpitSnapshotOptions.fromJson(finalSnapshotOptionsJson),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }

  CockpitInteractiveBatchCommand _readBatchCommand(Map<String, Object?> json) {
    final commandJson = json['command'];
    final normalizedCommandJson = commandJson is Map<Object?, Object?>
        ? Map<String, Object?>.from(commandJson)
        : json;
    final snapshotOptionsJson = json['snapshotOptions'];
    return CockpitInteractiveBatchCommand(
      command: CockpitCommand.fromJson(normalizedCommandJson),
      resultProfile: json['profile'] == null
          ? null
          : CockpitInteractiveResultProfile.preset(
              CockpitInteractiveResultProfileName.fromJson(json['profile']),
            ),
      snapshotOptions: snapshotOptionsJson is Map<Object?, Object?>
          ? CockpitSnapshotOptions.fromJson(
              Map<String, Object?>.from(snapshotOptionsJson),
            )
          : null,
      compareAgainstSnapshotRef: json['compareAgainstSnapshotRef'] as String?,
    );
  }

  CockpitInteractiveResultProfile? _readOptionalProfile(Object? value) {
    if (value == null) {
      return null;
    }
    return CockpitInteractiveResultProfile.preset(
      CockpitInteractiveResultProfileName.fromJson(value),
    );
  }
}
