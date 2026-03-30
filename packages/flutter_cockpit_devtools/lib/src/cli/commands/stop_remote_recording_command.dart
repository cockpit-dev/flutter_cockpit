import 'dart:io';
import 'dart:convert';

import 'package:args/command_runner.dart';

import '../../application/cockpit_stop_remote_recording_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStopRemoteRecordingFunction
    = Future<CockpitStopRemoteRecordingResult> Function(
  CockpitStopRemoteRecordingRequest request,
);

final class StopRemoteRecordingCommand extends Command<int> {
  StopRemoteRecordingCommand({
    CockpitStopRemoteRecordingService? service,
    CockpitStopRemoteRecordingFunction? stop,
    StringSink? stdoutSink,
  })  : _stop = stop ?? (service ?? CockpitStopRemoteRecordingService()).stop,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddRemoteSessionArgs(argParser);
  }

  final CockpitStopRemoteRecordingFunction _stop;
  final StringSink _stdoutSink;

  @override
  String get name => 'stop-remote-recording';

  @override
  String get description =>
      'Stop the active on-demand remote recording session and return artifact metadata.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final result = await _stop(
      CockpitStopRemoteRecordingRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: argResults?['session-json'] as String?,
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
