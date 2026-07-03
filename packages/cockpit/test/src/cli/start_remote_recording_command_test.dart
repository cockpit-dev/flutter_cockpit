import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_start_remote_recording_service.dart';
import 'package:cockpit/src/cli/commands/start_remote_recording_command.dart';
import 'package:test/test.dart';

void main() {
  test('start-remote-recording parses recording JSON', () async {
    CockpitStartRemoteRecordingRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        StartRemoteRecordingCommand(
          stdoutSink: stdoutBuffer,
          start: (request) async {
            capturedRequest = request;
            return CockpitStartRemoteRecordingResult(
              recordingSession: CockpitRecordingSession(
                request: request.recording,
                state: CockpitRecordingState.recording,
              ),
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'start-remote-recording',
          '--stdout-format',
          'json',
          '--base-url',
          'http://127.0.0.1:47331',
          '--recording-json',
          jsonEncode(const <String, Object?>{
            'purpose': 'acceptance',
            'name': 'debug-pass',
          }),
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.recording.name, 'debug-pass');
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['recordingSession'], isA<Map<String, Object?>>());
  });
}
