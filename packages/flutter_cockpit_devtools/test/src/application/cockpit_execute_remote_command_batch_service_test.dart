import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_batch_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitExecuteRemoteCommandBatchService', () {
    test(
      'executes commands in order and stops early when failFast is true',
      () async {
        final executed = <String>[];
        final service = CockpitExecuteRemoteCommandBatchService(
          executeCommand: (_, command) async {
            executed.add(command.commandId);
            final success = command.commandId != 'second';
            return CockpitCommandExecution(
              result: CockpitCommandResult(
                success: success,
                commandId: command.commandId,
                commandType: command.commandType,
                durationMs: 40,
              ),
            );
          },
        );

        final result = await service.execute(
          CockpitExecuteRemoteCommandBatchRequest(
            sessionHandle: _sessionHandle(),
            defaultResultProfile:
                const CockpitInteractiveResultProfile.minimal(),
            commands: <CockpitInteractiveBatchCommand>[
              _batchCommand('first'),
              _batchCommand('second'),
              _batchCommand('third'),
            ],
            failFast: true,
          ),
        );

        expect(executed, <String>['first', 'second']);
        expect(result.results.length, 2);
        expect(result.summary.stoppedEarly, isTrue);
        expect(result.summary.failureCount, 1);
      },
    );

    test('continues after failures when failFast is false', () async {
      final executed = <String>[];
      final service = CockpitExecuteRemoteCommandBatchService(
        executeCommand: (_, command) async {
          executed.add(command.commandId);
          final success = command.commandId != 'second';
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: success,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 40,
            ),
          );
        },
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandBatchRequest(
          sessionHandle: _sessionHandle(),
          defaultResultProfile: const CockpitInteractiveResultProfile.minimal(),
          commands: <CockpitInteractiveBatchCommand>[
            _batchCommand('first'),
            _batchCommand('second'),
            _batchCommand('third'),
          ],
          failFast: false,
        ),
      );

      expect(executed, <String>['first', 'second', 'third']);
      expect(result.results.length, 3);
      expect(result.summary.stoppedEarly, isFalse);
      expect(result.summary.failureCount, 1);
    });

    test('applies batch defaults and per-command overrides', () async {
      final service = CockpitExecuteRemoteCommandBatchService(
        executeCommand: (_, command) async {
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 40,
            ),
          );
        },
        readSnapshot: (_, options) async => CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(
            routeName: '/${options.profile.jsonValue}',
            diagnosticLevel: options.profile,
            visibleTargets: <CockpitSnapshotTarget>[
              CockpitSnapshotTarget(
                registrationId: 'target-1',
                routeName: '/${options.profile.jsonValue}',
                text: options.profile.jsonValue,
              ),
            ],
          ),
        ),
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandBatchRequest(
          sessionHandle: _sessionHandle(),
          defaultResultProfile: const CockpitInteractiveResultProfile.inspect(),
          commands: <CockpitInteractiveBatchCommand>[
            _batchCommand('first'),
            _batchCommand(
              'second',
              resultProfile: const CockpitInteractiveResultProfile.minimal(),
            ),
          ],
        ),
      );

      expect(result.results.first.uiSummary?.routeName, '/investigate');
      expect(result.results[1].uiSummary, isNull);
    });

    test(
      'injects the batch default timeout into commands that omit one',
      () async {
        final timeouts = <int?>[];
        final service = CockpitExecuteRemoteCommandBatchService(
          executeCommand: (_, command) async {
            timeouts.add(command.timeoutMs);
            return CockpitCommandExecution(
              result: CockpitCommandResult(
                success: true,
                commandId: command.commandId,
                commandType: command.commandType,
                durationMs: 40,
              ),
            );
          },
        );

        await service.execute(
          CockpitExecuteRemoteCommandBatchRequest(
            sessionHandle: _sessionHandle(),
            defaultResultProfile:
                const CockpitInteractiveResultProfile.minimal(),
            commands: <CockpitInteractiveBatchCommand>[
              _batchCommand('default-timeout'),
              CockpitInteractiveBatchCommand(
                command: CockpitCommand(
                  commandId: 'explicit-timeout',
                  commandType: CockpitCommandType.tap,
                  timeoutMs: 9000,
                ),
              ),
            ],
            defaultCommandTimeout: const Duration(milliseconds: 4700),
          ),
        );

        expect(timeouts, <int?>[4700, 9000]);
      },
    );

    test('captures a final snapshot when requested', () async {
      final service = CockpitExecuteRemoteCommandBatchService(
        executeCommand: (_, command) async {
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 40,
            ),
          );
        },
        readSnapshot: (_, options) async => CockpitRemoteSnapshotResponse(
          snapshot: CockpitSnapshot(
            routeName: options.profile == CockpitSnapshotProfile.baseline
                ? '/final'
                : '/step',
            diagnosticLevel: options.profile,
          ),
        ),
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandBatchRequest(
          sessionHandle: _sessionHandle(),
          commands: <CockpitInteractiveBatchCommand>[_batchCommand('first')],
          finalSnapshotProfile:
              const CockpitInteractiveResultProfile.standard(),
        ),
      );

      expect(result.finalSnapshot?.routeName, '/final');
      expect(result.finalSnapshot?.snapshotRef, isNotEmpty);
    });

    test('stops active recording when a batch command throws', () async {
      var started = false;
      var stopped = false;
      final service = CockpitExecuteRemoteCommandBatchService(
        startRecording: (_, request) async {
          started = true;
          return CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          );
        },
        stopRecording: (_) async {
          stopped = true;
          return CockpitRecordingResult(state: CockpitRecordingState.completed);
        },
        executeCommand: (_, _) async {
          throw StateError('command failed');
        },
      );

      await expectLater(
        service.execute(
          CockpitExecuteRemoteCommandBatchRequest(
            sessionHandle: _sessionHandle(),
            commands: <CockpitInteractiveBatchCommand>[
              _batchCommand('explodes'),
            ],
            recording: _recordingRequest(),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'command failed',
          ),
        ),
      );

      expect(started, isTrue);
      expect(stopped, isTrue);
    });

    test('preserves command failure when cleanup stop also fails', () async {
      var stopAttempts = 0;
      final service = CockpitExecuteRemoteCommandBatchService(
        startRecording: (_, request) async => CockpitRecordingSession(
          request: request,
          state: CockpitRecordingState.recording,
        ),
        stopRecording: (_) async {
          stopAttempts += 1;
          throw StateError('stop failed');
        },
        executeCommand: (_, _) async {
          throw StateError('original command failure');
        },
      );

      await expectLater(
        service.execute(
          CockpitExecuteRemoteCommandBatchRequest(
            sessionHandle: _sessionHandle(),
            commands: <CockpitInteractiveBatchCommand>[
              _batchCommand('explodes'),
            ],
            recording: _recordingRequest(),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'original command failure',
          ),
        ),
      );

      expect(stopAttempts, 1);
    });
  });
}

CockpitInteractiveBatchCommand _batchCommand(
  String commandId, {
  CockpitInteractiveResultProfile? resultProfile,
}) {
  return CockpitInteractiveBatchCommand(
    command: CockpitCommand(
      commandId: commandId,
      commandType: CockpitCommandType.tap,
    ),
    resultProfile: resultProfile,
  );
}

CockpitRemoteSessionHandle _sessionHandle() {
  return CockpitRemoteSessionHandle(
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    appId: 'dev.cockpit.demo',
    host: '127.0.0.1',
    hostPort: 47331,
    devicePort: 47331,
    baseUrl: 'http://127.0.0.1:47331',
    launchedAt: DateTime.utc(2026, 3, 30),
  );
}

CockpitRecordingRequest _recordingRequest() {
  return const CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'batch-cleanup',
  );
}
