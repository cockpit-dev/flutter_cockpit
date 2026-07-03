import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_interactive_result_data.dart';
import 'package:cockpit/src/application/cockpit_stop_remote_recording_service.dart';
import 'package:cockpit/src/cli/commands/stop_remote_recording_command.dart';
import 'package:test/test.dart';

void main() {
  test('stop-remote-recording writes artifact metadata', () async {
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        StopRemoteRecordingCommand(
          stdoutSink: stdoutBuffer,
          stop: (_) async => const CockpitStopRemoteRecordingResult(
            state: CockpitRecordingState.completed,
            artifact: CockpitInteractiveArtifactDescriptor(
              role: 'recording',
              relativePath: 'recordings/final.mp4',
              byteLength: 4,
              sourcePath: '/tmp/final.mp4',
            ),
          ),
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'stop-remote-recording',
          '--stdout-format',
          'json',
          '--base-url',
          'http://127.0.0.1:47331',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['artifact'], isA<Map<String, Object?>>());
  });
}
