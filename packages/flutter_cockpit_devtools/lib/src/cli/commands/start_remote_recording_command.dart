import 'dart:io';
import 'dart:convert';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_start_remote_recording_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStartRemoteRecordingFunction
    = Future<CockpitStartRemoteRecordingResult> Function(
  CockpitStartRemoteRecordingRequest request,
);

final class StartRemoteRecordingCommand extends CockpitCliCommand {
  StartRemoteRecordingCommand({
    CockpitStartRemoteRecordingService? service,
    CockpitStartRemoteRecordingFunction? start,
    StringSink? stdoutSink,
  })  : _start =
            start ?? (service ?? CockpitStartRemoteRecordingService()).start,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    argParser
      ..addOption(
        'recording-json',
        help: 'Inline JSON object that describes the recording request.',
      )
      ..addOption(
        'recording-file',
        help: 'Path to a JSON recording request.',
      );
  }

  final CockpitStartRemoteRecordingFunction _start;
  final StringSink _stdoutSink;

  @override
  String get name => 'start-remote-recording';

  @override
  String get description =>
      'Start an on-demand remote recording session for interactive debugging.';

  @override
  String get summary => 'Start remote recording.';

  @override
  String get category => CockpitCliCategory.evidence;

  @override
  String get helpWhen =>
      'Use only when motion, transition, or acceptance proof needs video from a direct remote session.';

  @override
  String get helpNeeds =>
      'A remote session reference and recording JSON with purpose and name.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools start-remote-recording --session-json /tmp/session.json --recording-json \'{"purpose":"acceptance","name":"acceptance"}\'';

  @override
  String get helpWrites =>
      'A recording session payload; stop-remote-recording finalizes artifact metadata.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final recordingJson = await cockpitReadRequiredJsonObject(
      argResults: argResults,
      inlineOption: 'recording-json',
      fileOption: 'recording-file',
      label: 'recording JSON',
      usage: usage,
    );
    final result = await _start(
      CockpitStartRemoteRecordingRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: cockpitResolveRemoteSessionHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        recording: CockpitRecordingRequest.fromJson(recordingJson),
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
