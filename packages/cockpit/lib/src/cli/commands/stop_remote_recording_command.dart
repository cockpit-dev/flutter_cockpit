import 'dart:io';
import 'dart:convert';

import '../../application/cockpit_stop_remote_recording_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStopRemoteRecordingFunction =
    Future<CockpitStopRemoteRecordingResult> Function(
      CockpitStopRemoteRecordingRequest request,
    );

final class StopRemoteRecordingCommand extends CockpitCliCommand {
  StopRemoteRecordingCommand({
    CockpitStopRemoteRecordingService? service,
    CockpitStopRemoteRecordingFunction? stop,
    StringSink? stdoutSink,
  }) : _stop = stop ?? (service ?? CockpitStopRemoteRecordingService()).stop,
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
  String get summary => 'Stop remote recording.';

  @override
  String get category => CockpitCliCategory.evidence;

  @override
  String get helpWhen =>
      'Use after start-remote-recording to finalize video evidence for a direct remote session.';

  @override
  String get helpNeeds =>
      'A remote session reference with an active recording.';

  @override
  String get helpExample =>
      'cockpit stop-remote-recording --session-json /tmp/session.json';

  @override
  String get helpWrites =>
      'Recording result JSON with artifact descriptors, download refs, and failure reason when evidence is invalid.';

  @override
  Future<int> run() async {
    cockpitRequireRemoteSessionReference(argResults, usage);
    final result = await _stop(
      CockpitStopRemoteRecordingRequest(
        baseUri: cockpitReadOptionalBaseUri(argResults),
        sessionHandlePath: cockpitResolveRemoteSessionHandlePath(argResults),
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
