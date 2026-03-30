import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_interactive_result_profile.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_run_batch_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitRunBatchFunction = Future<CockpitRunBatchResult> Function(
  CockpitRunBatchRequest request,
);

final class RunBatchCommand extends Command<int> {
  RunBatchCommand({
    CockpitRunBatchService? service,
    CockpitRunBatchFunction? runBatch,
    StringSink? stdoutSink,
  })  : _runBatch = runBatch ?? (service ?? CockpitRunBatchService()).run,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    cockpitAddProfileArg(argParser);
    argParser
      ..addOption('commands-json')
      ..addOption('commands-file')
      ..addFlag('fail-fast', defaultsTo: true)
      ..addOption('recording-json')
      ..addOption('recording-file')
      ..addOption('final-profile')
      ..addOption('final-snapshot-options-json')
      ..addOption('final-snapshot-options-file');
  }

  final CockpitRunBatchFunction _runBatch;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-batch';

  @override
  String get description =>
      'Execute multiple cockpit commands in order against a running app.';

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
        recording: recordingJson == null
            ? null
            : CockpitRecordingRequest.fromJson(
                cockpitNormalizeJsonKeys(recordingJson),
              ),
        finalSnapshotProfile:
            _readOptionalProfile(argResults?['final-profile']),
        finalSnapshotOptions: finalSnapshotOptionsJson == null
            ? null
            : CockpitSnapshotOptions.fromJson(
                cockpitNormalizeJsonKeys(finalSnapshotOptionsJson),
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
    final normalizedJson = cockpitNormalizeJsonKeys(json);
    final commandJson = normalizedJson['command'];
    final normalized = commandJson is Map<Object?, Object?>
        ? Map<String, Object?>.from(commandJson)
        : normalizedJson;
    final snapshotOptionsJson = normalizedJson['snapshotOptions'];
    return CockpitRunBatchCommand(
      command: CockpitCommand.fromJson(normalized),
      resultProfile: _readOptionalProfile(normalizedJson['resultProfile']),
      snapshotOptions: snapshotOptionsJson is Map<Object?, Object?>
          ? CockpitSnapshotOptions.fromJson(
              cockpitNormalizeJsonKeys(
                Map<String, Object?>.from(snapshotOptionsJson),
              ),
            )
          : null,
      compareAgainstSnapshotRef:
          normalizedJson['compareAgainstSnapshotRef'] as String?,
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
