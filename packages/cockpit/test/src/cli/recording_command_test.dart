import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/cli/commands/run_batch_command.dart';
import 'package:cockpit/src/cli/commands/start_recording_command.dart';
import 'package:cockpit/src/cli/commands/stop_recording_command.dart';
import 'package:test/test.dart';

void main() {
  test(
    'start-recording defaults to an AI-first development recording request',
    () async {
      CockpitStartRecordingRequest? capturedRequest;
      final stdoutBuffer = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          StartRecordingCommand(
            stdoutSink: stdoutBuffer,
            start: (request) async {
              capturedRequest = request;
              return CockpitStartRecordingResult(
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
            'start-recording',
            '--stdout-format',
            'json',
            '--base-url',
            'http://127.0.0.1:47331',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.recording.purpose, CockpitRecordingPurpose.repro);
      expect(capturedRequest?.recording.mode, CockpitRecordingMode.auto);
      expect(
        capturedRequest?.recording.tailStabilizationDelay.inMilliseconds,
        1400,
      );
      expect(
        capturedRequest?.recording.name,
        matches(RegExp(r'^\d{8}T\d{12}Z_development-recording$')),
      );
      final decoded =
          jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
      expect(decoded['recordingSession'], isA<Map<String, Object?>>());
    },
  );

  test('start-recording forwards explicit iOS device ids', () async {
    CockpitStartRecordingRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        StartRecordingCommand(
          stdoutSink: stdoutBuffer,
          start: (request) async {
            capturedRequest = request;
            return CockpitStartRecordingResult(
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
          'start-recording',
          '--stdout-format',
          'json',
          '--base-url',
          'http://127.0.0.1:47331',
          '--ios-device-id',
          '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
          '--recording-json',
          jsonEncode(const <String, Object?>{
            'purpose': 'acceptance',
            'name': 'ios-flow',
          }),
        ]) ??
        0;

    expect(exitCode, 0);
    expect(
      capturedRequest?.iosDeviceId,
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
    );
    expect(capturedRequest?.recording.name, 'ios-flow');
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['recordingSession'], isA<Map<String, Object?>>());
  });

  test('stop-recording forwards explicit iOS device ids', () async {
    CockpitStopRecordingRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        StopRecordingCommand(
          stdoutSink: stdoutBuffer,
          stop: (request) async {
            capturedRequest = request;
            return const CockpitStopRecordingResult(
              state: CockpitRecordingState.completed,
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'stop-recording',
          '--stdout-format',
          'json',
          '--base-url',
          'http://127.0.0.1:47331',
          '--ios-device-id',
          '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(
      capturedRequest?.iosDeviceId,
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
    );
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['state'], CockpitRecordingState.completed.name);
  });

  test(
    'run-batch forwards explicit iOS device ids for batch recording',
    () async {
      CockpitRunBatchRequest? capturedRequest;
      final stdoutBuffer = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          RunBatchCommand(
            stdoutSink: stdoutBuffer,
            runBatch: (request) async {
              capturedRequest = request;
              return const CockpitRunBatchResult(
                results: <CockpitRunCommandResult>[],
                summary: CockpitExecuteRemoteCommandBatchSummary(
                  totalCount: 0,
                  successCount: 0,
                  failureCount: 0,
                  stoppedEarly: false,
                ),
              );
            },
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'run-batch',
            '--stdout-format',
            'json',
            '--base-url',
            'http://127.0.0.1:47331',
            '--ios-device-id',
            '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
            '--commands-json',
            jsonEncode(const <Map<String, Object?>>[
              <String, Object?>{
                'commandId': 'wait-1',
                'commandType': 'waitForUiIdle',
              },
            ]),
            '--recording-json',
            jsonEncode(const <String, Object?>{
              'purpose': 'acceptance',
              'name': 'ios-batch',
            }),
          ]) ??
          0;

      expect(exitCode, 0);
      expect(
        capturedRequest?.iosDeviceId,
        '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      );
      expect(capturedRequest?.recording?.name, 'ios-batch');
      final decoded =
          jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
      expect(decoded['summary'], isA<Map<String, Object?>>());
    },
  );

  test(
    'run-batch reports non-object command entries as usage errors',
    () async {
      final stderrBuffer = StringBuffer();
      final runner = CockpitCommandRunner(stderrSink: stderrBuffer);

      final exitCode = await runner.run(<String>[
        'run-batch',
        '--base-url',
        'http://127.0.0.1:47331',
        '--commands-json',
        jsonEncode(<Object?>[
          <String, Object?>{
            'commandId': 'wait-1',
            'commandType': 'waitForUiIdle',
          },
          'not-a-command-object',
        ]),
      ]);

      expect(exitCode, cockpitUsageExitCode);
      final stderr = stderrBuffer.toString();
      expect(stderr, contains('commands JSON item at index 1'));
      final jsonLine = stderr
          .split('\n')
          .firstWhere((line) => line.startsWith('errorJson: '));
      final payload = Map<String, Object?>.from(
        jsonDecode(jsonLine.substring('errorJson: '.length))
            as Map<Object?, Object?>,
      );
      expect(payload['code'], 'usage');
      expect(payload['message'], contains('commands JSON item at index 1'));
    },
  );
}
