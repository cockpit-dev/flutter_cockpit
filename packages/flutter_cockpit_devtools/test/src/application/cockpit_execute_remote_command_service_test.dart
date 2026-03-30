import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_execute_remote_command_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_snapshot_store.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitExecuteRemoteCommandService', () {
    test('executes a command with compact results by default', () async {
      final handle = _sessionHandle();
      Uri? capturedBaseUri;
      CockpitCommand? capturedCommand;
      var snapshotReads = 0;
      final service = CockpitExecuteRemoteCommandService(
        executeCommand: (baseUri, command) async {
          capturedBaseUri = baseUri;
          capturedCommand = command;
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 120,
            ),
          );
        },
        readSnapshot: (_, __) async {
          snapshotReads += 1;
          throw UnimplementedError('compact results should not read snapshots');
        },
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandRequest(
          sessionHandle: handle,
          command: CockpitCommand(
            commandId: 'tap-1',
            commandType: CockpitCommandType.tap,
          ),
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(capturedBaseUri, handle.baseUri);
      expect(capturedCommand?.commandId, 'tap-1');
      expect(snapshotReads, 0);
      expect(result.command.commandId, 'tap-1');
      expect(result.command.success, isTrue);
      expect(result.uiSummary, isNull);
      expect(result.snapshot, isNull);
      expect(result.diagnostics, isNull);
      expect(result.artifacts, isEmpty);
      expect(result.snapshotRef, isNull);
    });

    test('returns summary, diagnostics, artifact metadata, and snapshot refs',
        () async {
      final handle = _sessionHandle();
      CockpitSnapshotOptions? capturedOptions;
      final service = CockpitExecuteRemoteCommandService(
        executeCommand: (_, command) async {
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 240,
              artifacts: const <CockpitArtifactRef>[
                CockpitArtifactRef(
                  role: 'step_screenshot',
                  relativePath: 'artifacts/after-tap.png',
                ),
              ],
            ),
            artifactPayloads: <String, List<int>>{
              'artifacts/after-tap.png': <int>[1, 2, 3, 4],
            },
          );
        },
        readSnapshot: (_, options) async {
          capturedOptions = options;
          return CockpitRemoteSnapshotResponse(
            snapshot: _richSnapshot(routeName: '/details'),
          );
        },
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandRequest(
          sessionHandle: handle,
          command: CockpitCommand(
            commandId: 'tap-2',
            commandType: CockpitCommandType.tap,
          ),
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );

      expect(capturedOptions?.profile, CockpitSnapshotProfile.investigate);
      expect(result.uiSummary?.routeName, '/details');
      expect(result.snapshot, isNull);
      expect(result.diagnostics?['network'], isNotNull);
      expect(result.artifacts.single.byteLength, 4);
      expect(result.snapshotRef, isNotEmpty);
      expect(result.effectiveSnapshotOptions?.profile,
          CockpitSnapshotProfile.investigate);
    });

    test('returns a full snapshot for forensic profiles', () async {
      final handle = _sessionHandle();
      final service = CockpitExecuteRemoteCommandService(
        executeCommand: (_, command) async {
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 80,
            ),
          );
        },
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: _richSnapshot(routeName: '/forensic'),
        ),
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandRequest(
          sessionHandle: handle,
          command: CockpitCommand(
            commandId: 'tap-3',
            commandType: CockpitCommandType.tap,
          ),
          resultProfile: const CockpitInteractiveResultProfile.evidence(),
        ),
      );

      expect(result.snapshot?.routeName, '/forensic');
      expect(result.uiSummary, isNull);
      expect(result.diagnostics?['runtime'], isNotNull);
    });

    test('returns refs without metadata for standard artifact profiles',
        () async {
      final service = CockpitExecuteRemoteCommandService(
        executeCommand: (_, command) async {
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 50,
              artifacts: const <CockpitArtifactRef>[
                CockpitArtifactRef(
                  role: 'step_screenshot',
                  relativePath: 'artifacts/standard.png',
                ),
              ],
            ),
            artifactPayloads: <String, List<int>>{
              'artifacts/standard.png': <int>[1, 2, 3],
            },
            artifactSourcePaths: <String, String>{
              'artifacts/standard.png': '/tmp/standard.png',
            },
          );
        },
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: _richSnapshot(routeName: '/standard'),
        ),
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandRequest(
          sessionHandle: _sessionHandle(),
          command: CockpitCommand(
            commandId: 'tap-standard',
            commandType: CockpitCommandType.tap,
          ),
          resultProfile: const CockpitInteractiveResultProfile.standard(),
        ),
      );

      expect(result.artifacts.single.role, 'step_screenshot');
      expect(result.artifacts.single.relativePath, 'artifacts/standard.png');
      expect(result.artifacts.single.byteLength, isNull);
      expect(result.artifacts.single.sourcePath, isNull);
    });

    test('filters failures-only diagnostics down to failing sections',
        () async {
      final service = CockpitExecuteRemoteCommandService(
        executeCommand: (_, command) async {
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 75,
            ),
          );
        },
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: _richSnapshot(routeName: '/failures-only'),
        ),
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandRequest(
          sessionHandle: _sessionHandle(),
          command: CockpitCommand(
            commandId: 'tap-inspect',
            commandType: CockpitCommandType.tap,
          ),
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
        ),
      );

      expect(result.diagnostics?['level'], 'failures_only');
      expect(result.diagnostics?['network'], isNotNull);
      expect(result.diagnostics?['runtime'], isNotNull);
      expect(result.diagnostics?.containsKey('rebuild'), isFalse);
      expect(result.diagnostics?.containsKey('accessibility'), isFalse);
    });

    test('propagates structured application errors', () async {
      final service = CockpitExecuteRemoteCommandService(
        executeCommand: (_, __) async {
          throw const CockpitApplicationServiceException(
            code: 'sessionUnreachable',
            message: 'Session is offline.',
          );
        },
      );

      expect(
        () => service.execute(
          CockpitExecuteRemoteCommandRequest(
            sessionHandle: _sessionHandle(),
            command: CockpitCommand(
              commandId: 'tap-4',
              commandType: CockpitCommandType.tap,
            ),
          ),
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'sessionUnreachable',
          ),
        ),
      );
    });

    test('fails when comparing against a missing snapshot ref', () async {
      final service = CockpitExecuteRemoteCommandService(
        executeCommand: (_, command) async {
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 120,
            ),
          );
        },
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: _richSnapshot(routeName: '/compare'),
        ),
      );

      expect(
        () => service.execute(
          CockpitExecuteRemoteCommandRequest(
            sessionHandle: _sessionHandle(),
            command: CockpitCommand(
              commandId: 'tap-5',
              commandType: CockpitCommandType.tap,
            ),
            resultProfile: const CockpitInteractiveResultProfile.inspect(),
            compareAgainstSnapshotRef: 'missing-snapshot-ref',
          ),
        ),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'interactiveSnapshotRefNotFound',
          ),
        ),
      );
    });

    test('includes deltas when comparing against a previous snapshot ref',
        () async {
      final store = CockpitInteractiveSnapshotStore();
      final baselineRef = store.put(
        sessionKey: _sessionHandle().baseUri.toString(),
        snapshot: _richSnapshot(routeName: '/before', label: 'Before'),
      );
      final service = CockpitExecuteRemoteCommandService(
        snapshotStore: store,
        executeCommand: (_, command) async {
          return CockpitCommandExecution(
            result: CockpitCommandResult(
              success: true,
              commandId: command.commandId,
              commandType: command.commandType,
              durationMs: 95,
            ),
          );
        },
        readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
          snapshot: _richSnapshot(routeName: '/after', label: 'After'),
        ),
      );

      final result = await service.execute(
        CockpitExecuteRemoteCommandRequest(
          sessionHandle: _sessionHandle(),
          command: CockpitCommand(
            commandId: 'tap-6',
            commandType: CockpitCommandType.tap,
          ),
          resultProfile: const CockpitInteractiveResultProfile.inspect(),
          compareAgainstSnapshotRef: baselineRef,
        ),
      );

      expect(result.delta?.routeChanged, isTrue);
      expect(result.delta?.fromRouteName, '/before');
      expect(result.delta?.toRouteName, '/after');
      expect(result.delta?.addedTextPreviews, contains('After'));
    });
  });
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

CockpitSnapshot _richSnapshot({
  required String routeName,
  String label = 'Inbox',
}) {
  return CockpitSnapshot(
    routeName: routeName,
    diagnosticLevel: CockpitSnapshotProfile.investigate,
    visibleTargets: <CockpitSnapshotTarget>[
      CockpitSnapshotTarget(
        registrationId: 'target-1',
        routeName: routeName,
        text: label,
        cockpitId: 'primary-button',
      ),
    ],
    summary: const CockpitSnapshotSummary(
      visibleTargetCount: 1,
      targetsWithCockpitIdCount: 1,
      targetsWithTextCount: 1,
      styleDetailsIncluded: true,
      diagnosticPropertiesIncluded: true,
      ancestorSummariesIncluded: false,
      rebuildSummaryIncluded: true,
      accessibilitySummaryIncluded: true,
    ),
    network: const CockpitNetworkSnapshot(
      totalEntryCount: 2,
      failureCount: 1,
      entries: <CockpitNetworkEntry>[],
      capturedEntryCount: 2,
      inFlightCount: 0,
      truncated: false,
    ),
    runtime: const CockpitRuntimeSnapshot(
      totalEntryCount: 1,
      errorCount: 1,
      warningCount: 0,
      entries: <CockpitRuntimeEvent>[],
      capturedEntryCount: 1,
      truncated: false,
    ),
    rebuild: const CockpitRebuildSnapshot(
      totalRebuildCount: 3,
      uniqueElementCount: 1,
      capturedEntryCount: 1,
      truncated: false,
      entries: <CockpitRebuildEntry>[],
    ),
    accessibility: CockpitAccessibilitySummary(
      totalAccessibleTargetCount: 1,
      traversalEntries: const <CockpitAccessibilityEntry>[
        CockpitAccessibilityEntry(nodeId: 1, label: 'Inbox'),
      ],
      truncated: false,
    ),
  );
}
