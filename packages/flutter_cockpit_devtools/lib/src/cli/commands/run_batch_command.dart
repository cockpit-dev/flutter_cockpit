import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_run_batch_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitRunBatchFunction = Future<CockpitRunBatchResult> Function(
  CockpitRunBatchRequest request,
);

final class RunBatchCommand extends CockpitCliCommand {
  RunBatchCommand({
    CockpitRunBatchService? service,
    CockpitRunBatchFunction? runBatch,
    StringSink? stdoutSink,
  })  : _runBatch = runBatch ?? (service ?? CockpitRunBatchService()).run,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    cockpitAddProfileArg(argParser);
    cockpitAddCommandsJsonArgs(argParser);
    cockpitAddCommandTimeoutArg(
      argParser,
      optionName: 'default-timeout-ms',
      help: 'Default timeout in milliseconds for commands that omit timeoutMs.',
    );
    argParser.addFlag(
      'fail-fast',
      defaultsTo: true,
      help:
          'Stop after the first failed command instead of finishing the full batch.',
    );
    cockpitAddRecordingArgs(argParser);
    argParser.addOption(
      'final-profile',
      help:
          'Optional result profile for the final snapshot emitted after the batch.',
    );
    cockpitAddSnapshotOptionsArgs(
      argParser,
      inlineOption: 'final-snapshot-options-json',
      fileOption: 'final-snapshot-options-file',
    );
  }

  final CockpitRunBatchFunction _runBatch;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-batch';

  @override
  String get description =>
      'Execute multiple cockpit commands in order against a running app.';

  @override
  String get summary => 'Run multiple commands in order.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use for short deterministic sequences where one command per round-trip is too slow.';

  @override
  String get helpNeeds =>
      'An app reference plus a JSON array from --commands-json or --commands-file.';

  @override
  String get helpShape =>
      'commands.json = [{"commandId":"open-today","commandType":"tap","locator":{"text":"Today","type":"NavigationDestinationLabel"}}]; each item may also set timeoutMs, profile, snapshotOptions, or compareAgainstSnapshotRef.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-batch --app-json /tmp/app.json --commands-file /tmp/commands.json --profile minimal';

  @override
  String get helpWrites =>
      'Per-command results, a batch summary, and an optional final snapshot layer.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final commandsJson = await cockpitReadRequiredJsonObjectList(
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
    final result = await _runBatch(
      CockpitRunBatchRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: argResults?['app-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
        commands: commandsJson.map(_readBatchCommand).toList(growable: false),
        defaultResultProfile: cockpitReadResultProfile(argResults),
        failFast: argResults?['fail-fast'] as bool? ?? true,
        defaultCommandTimeout: Duration(
          milliseconds:
              cockpitReadOptionalInt(argResults, 'default-timeout-ms') ?? 30000,
        ),
        recording: recordingJson == null
            ? null
            : CockpitRecordingRequest.fromJson(recordingJson),
        finalSnapshotProfile:
            _readOptionalProfile(argResults?['final-profile']),
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

  CockpitRunBatchCommand _readBatchCommand(Map<String, Object?> json) {
    final commandJson = json['command'];
    final normalized = commandJson is Map<Object?, Object?>
        ? Map<String, Object?>.from(commandJson)
        : json;
    final snapshotOptionsJson = json['snapshotOptions'];
    return CockpitRunBatchCommand(
      command: CockpitCommand.fromJson(normalized),
      resultProfile: _readOptionalProfile(json['profile']),
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
