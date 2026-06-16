import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_stop_recording_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStopRecordingFunction =
    Future<CockpitStopRecordingResult> Function(
      CockpitStopRecordingRequest request,
    );

final class StopRecordingCommand extends CockpitCliCommand {
  StopRecordingCommand({
    CockpitStopRecordingService? service,
    CockpitStopRecordingFunction? stop,
    StringSink? stdoutSink,
  }) : _stop = stop ?? (service ?? CockpitStopRecordingService()).stop,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
  }

  final CockpitStopRecordingFunction _stop;
  final StringSink _stdoutSink;

  @override
  String get name => 'stop-recording';

  @override
  String get description => 'Stop the active recording session.';

  @override
  String get summary => 'Stop recording and write artifacts.';

  @override
  String get category => CockpitCliCategory.evidence;

  @override
  String get helpWhen =>
      'Finalize the active recording after the interesting part of the flow has completed.';

  @override
  String get helpNeeds => 'An app reference with an active recording session.';

  @override
  String get helpExample => 'cockpit stop-recording --app-json /tmp/app.json';

  @override
  String get helpWrites =>
      'Recording completion data and artifact references for the emitted video.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final result = await _stop(
      CockpitStopRecordingRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        iosDeviceId: argResults?['ios-device-id'] as String?,
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
