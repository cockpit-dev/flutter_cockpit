import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_start_recording_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStartRecordingFunction = Future<CockpitStartRecordingResult>
    Function(
  CockpitStartRecordingRequest request,
);

final class StartRecordingCommand extends Command<int> {
  StartRecordingCommand({
    CockpitStartRecordingService? service,
    CockpitStartRecordingFunction? start,
    StringSink? stdoutSink,
  })  : _start = start ?? (service ?? CockpitStartRecordingService()).start,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser
      ..addOption('recording-json')
      ..addOption('recording-file');
  }

  final CockpitStartRecordingFunction _start;
  final StringSink _stdoutSink;

  @override
  String get name => 'start-recording';

  @override
  String get description => 'Start an on-demand recording session.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final recordingJson = await cockpitReadRequiredJsonObject(
      argResults: argResults,
      inlineOption: 'recording-json',
      fileOption: 'recording-file',
      label: 'recording JSON',
      usage: usage,
    );
    final result = await _start(
      CockpitStartRecordingRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: argResults?['app-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
        recording: CockpitRecordingRequest.fromJson(
          cockpitNormalizeJsonKeys(recordingJson),
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
}
