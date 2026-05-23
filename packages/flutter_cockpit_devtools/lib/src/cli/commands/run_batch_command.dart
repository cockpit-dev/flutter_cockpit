import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_run_batch_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitRunBatchFunction =
    Future<CockpitRunBatchResult> Function(CockpitRunBatchRequest request);

final class RunBatchCommand extends CockpitCliCommand {
  RunBatchCommand({
    CockpitRunBatchService? service,
    CockpitRunBatchFunction? runBatch,
    StringSink? stdoutSink,
  }) : _runBatch = runBatch ?? (service ?? CockpitRunBatchService()).run,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser.addOption(
      'ios-device-id',
      help:
          'iOS device or simulator ID for host-side batch recording when app metadata is unavailable.',
    );
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
      'Use for short deterministic route-crossing sequences where one command per round-trip is too slow or too fragile.';

  @override
  String get helpNeeds =>
      'An app reference plus a JSON array from --commands-json or --commands-file. Optional --recording-json or --recording-file wraps the whole batch in one capture.';

  @override
  String get helpShape =>
      'commands.json = [{"commandId":"wait-1","commandType":"waitForUiIdle"},{"commandId":"assert-ready","commandType":"assertText","parameters":{"text":"<expected-text>"}}]; prefer batch for short open -> edit -> save style flows. Each item may also set timeoutMs, profile, snapshotOptions, or compareAgainstSnapshotRef.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-batch --app-json /tmp/app.json --commands-file /tmp/commands.json --profile minimal';

  @override
  String get helpWrites =>
      'Per-command results, a batch summary, an optional final snapshot layer, and optional recording metadata when recording is requested.';

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
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
        commands: commandsJson.map(_readBatchCommand).toList(growable: false),
        defaultResultProfile: cockpitReadResultProfile(argResults),
        failFast: argResults?['fail-fast'] as bool? ?? true,
        defaultCommandTimeout: Duration(
          milliseconds:
              cockpitReadOptionalPositiveInt(
                argResults,
                'default-timeout-ms',
                usage,
              ) ??
              30000,
        ),
        recording: recordingJson == null
            ? null
            : cockpitDecodeCliJson(
                decode: () => CockpitRecordingRequest.fromJson(recordingJson),
                label: 'recording JSON',
                usage: usage,
              ),
        finalSnapshotProfile: _readOptionalProfile(
          argResults?['final-profile'],
        ),
        finalSnapshotOptions: finalSnapshotOptionsJson == null
            ? null
            : cockpitDecodeCliJson(
                decode: () =>
                    CockpitSnapshotOptions.fromJson(finalSnapshotOptionsJson),
                label: 'final snapshot options JSON',
                usage: usage,
              ),
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
      command: cockpitDecodeCliJson(
        decode: () => CockpitCommand.fromJson(normalized),
        label: 'commands JSON',
        usage: usage,
      ),
      resultProfile: _readOptionalProfile(json['profile']),
      snapshotOptions: snapshotOptionsJson is Map<Object?, Object?>
          ? cockpitDecodeCliJson(
              decode: () => CockpitSnapshotOptions.fromJson(
                Map<String, Object?>.from(snapshotOptionsJson),
              ),
              label: 'commands JSON',
              usage: usage,
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
