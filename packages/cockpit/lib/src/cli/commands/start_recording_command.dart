import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../application/cockpit_default_recording_request.dart';
import '../../application/cockpit_start_recording_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStartRecordingFunction =
    Future<CockpitStartRecordingResult> Function(
      CockpitStartRecordingRequest request,
    );

final class StartRecordingCommand extends CockpitCliCommand {
  StartRecordingCommand({
    CockpitStartRecordingService? service,
    CockpitStartRecordingFunction? start,
    StringSink? stdoutSink,
  }) : _start = start ?? (service ?? CockpitStartRecordingService()).start,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    cockpitAddRecordingArgs(argParser);
  }

  final CockpitStartRecordingFunction _start;
  final StringSink _stdoutSink;

  @override
  String get name => 'start-recording';

  @override
  String get description => 'Start an on-demand recording session.';

  @override
  String get summary => 'Begin on-demand screen recording.';

  @override
  String get category => CockpitCliCategory.evidence;

  @override
  String get helpWhen =>
      'Capture motion, transition, or development proof around a risky flow. Prefer a screenshot when one still state already answers the question.';

  @override
  String get helpNeeds =>
      'An app reference. Omit --recording-json for the default repro development recording; pass --recording-json or --recording-file for acceptance, full-screen, or strict layer control.';

  @override
  String get helpShape =>
      'Default recording = repro auto mode with a sortable name. Optional recording.json = {"purpose":"acceptance","name":"acceptance","tailStabilizationMs":1400}; purpose accepts acceptance or repro.';

  @override
  String get helpExample => 'cockpit start-recording';

  @override
  String get helpWrites =>
      'Recording session metadata only. Use stop-recording to finalize the artifact and collect the emitted video refs or paths.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final recordingJson = await cockpitReadOptionalJsonObject(
      argResults: argResults,
      inlineOption: 'recording-json',
      fileOption: 'recording-file',
      label: 'recording JSON',
      usage: usage,
    );
    final result = await _start(
      CockpitStartRecordingRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
        recording: recordingJson == null
            ? cockpitDefaultDevelopmentRecordingRequest()
            : cockpitDecodeCliJson(
                decode: () => CockpitRecordingRequest.fromJson(recordingJson),
                label: 'recording JSON',
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
}
