import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_batch_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitExecuteRemoteCommandBatchService', () {
    test('executes commands in order and stops early when failFast is true',
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
    });

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
              resultProfile: const CockpitInteractiveResultProfile.compact(),
            ),
          ],
        ),
      );

      expect(result.results.first.uiSummary?.routeName, '/investigate');
      expect(result.results[1].uiSummary, isNull);
    });

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
          commands: <CockpitInteractiveBatchCommand>[
            _batchCommand('first'),
          ],
          finalSnapshotProfile:
              const CockpitInteractiveResultProfile.standard(),
        ),
      );

      expect(result.finalSnapshot?.routeName, '/final');
      expect(result.finalSnapshot?.snapshotRef, isNotEmpty);
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
