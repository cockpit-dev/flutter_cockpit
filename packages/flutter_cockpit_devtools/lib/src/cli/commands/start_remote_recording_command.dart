import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_start_remote_recording_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStartRemoteRecordingFunction
    = Future<CockpitStartRemoteRecordingResult> Function(
  CockpitStartRemoteRecordingRequest request,
);

final class StartRemoteRecordingCommand extends Command<int> {
  StartRemoteRecordingCommand({
    CockpitStartRemoteRecordingService? service,
    CockpitStartRemoteRecordingFunction? start,
    StringSink? stdoutSink,
  })  : _start =
            start ?? (service ?? CockpitStartRemoteRecordingService()).start,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
    argParser
      ..addOption('recording-json')
      ..addOption('recording-file');
  }

  final CockpitStartRemoteRecordingFunction _start;
  final StringSink _stdoutSink;

  @override
  String get name => 'start-remote-recording';

  @override
  String get description =>
      'Start an on-demand remote recording session for interactive debugging.';

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
        sessionHandlePath: argResults?['session-json'] as String?,
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
