import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_stop_recording_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStopRecordingFunction = Future<CockpitStopRecordingResult>
    Function(
  CockpitStopRecordingRequest request,
);

final class StopRecordingCommand extends Command<int> {
  StopRecordingCommand({
    CockpitStopRecordingService? service,
    CockpitStopRecordingFunction? stop,
    StringSink? stdoutSink,
  })  : _stop = stop ?? (service ?? CockpitStopRecordingService()).stop,
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
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final result = await _stop(
      CockpitStopRecordingRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        appHandlePath: argResults?['app-json'] as String?,
        androidDeviceId: argResults?['android-device-id'] as String?,
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
