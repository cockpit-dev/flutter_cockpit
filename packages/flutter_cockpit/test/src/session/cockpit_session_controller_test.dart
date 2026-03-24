import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('records steps and exports a context bundle', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 20, 8, 0, 0),
      DateTime.utc(2026, 3, 20, 8, 0, 1),
      DateTime.utc(2026, 3, 20, 8, 0, 5),
    ].iterator;

    DateTime nextTimestamp() {
      final didMove = timestamps.moveNext();
      if (!didMove) {
        throw StateError('No more timestamps available.');
      }
      return timestamps.current;
    }

    final controller = CockpitSessionController(
      sessionId: 'session-001',
      taskId: 'task-login',
      platform: 'android',
      now: nextTimestamp,
    );

    controller.recordStep(
      actionType: 'tap',
      actionArgs: const {'target': 'login_button'},
      observation: CockpitObservation(
        routeName: '/login',
        interactiveElements: const ['login_button'],
      ),
    );

    final bundle = controller.finish(
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
    );

    expect(bundle.manifest.status, CockpitTaskStatus.completed);
    expect(bundle.manifest.startedAt, DateTime.utc(2026, 3, 20, 8, 0, 0));
    expect(bundle.manifest.finishedAt, DateTime.utc(2026, 3, 20, 8, 0, 5));
    expect(bundle.steps, hasLength(1));
    expect(bundle.steps.single.actionType, 'tap');
    expect(bundle.steps.single.observedAt, DateTime.utc(2026, 3, 20, 8, 0, 1));
    expect(bundle.observations, hasLength(1));
    expect(bundle.observations.single.routeName, '/login');
    expect(bundle.handoff['status'], 'completed');
  });

  test('finishWithFailure preserves recorded steps and failure summary', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 20, 8, 0, 0),
      DateTime.utc(2026, 3, 20, 8, 0, 4),
      DateTime.utc(2026, 3, 20, 8, 0, 9),
    ].iterator;

    DateTime nextTimestamp() {
      final didMove = timestamps.moveNext();
      if (!didMove) {
        throw StateError('No more timestamps available.');
      }
      return timestamps.current;
    }

    final controller = CockpitSessionController(
      sessionId: 'session-002',
      taskId: 'task-signup',
      platform: 'ios',
      now: nextTimestamp,
    );

    controller.recordStep(
      actionType: 'input',
      actionArgs: const {'field': 'email', 'value': 'broken@example.com'},
    );

    final bundle = controller.finishWithFailure(
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      failureSummary: 'Validation dialog never appeared.',
    );

    expect(bundle.manifest.status, CockpitTaskStatus.failed);
    expect(bundle.manifest.failureSummary, 'Validation dialog never appeared.');
    expect(bundle.steps, hasLength(1));
    expect(bundle.steps.single.actionType, 'input');
    expect(bundle.handoff['status'], 'failed');
  });

  test(
    'acceptance markdown includes captured network summary when available',
    () {
      final timestamps = <DateTime>[
        DateTime.utc(2026, 3, 21, 8, 10, 0),
        DateTime.utc(2026, 3, 21, 8, 10, 1),
        DateTime.utc(2026, 3, 21, 8, 10, 4),
      ].iterator;

      DateTime nextTimestamp() {
        final didMove = timestamps.moveNext();
        if (!didMove) {
          throw StateError('No more timestamps available.');
        }
        return timestamps.current;
      }

      final controller = CockpitSessionController(
        sessionId: 'session-network-001',
        taskId: 'task-sync-check',
        platform: 'android',
        now: nextTimestamp,
      );

      controller.recordStep(
        actionType: 'collectSnapshot',
        actionArgs: const {'profile': 'investigate'},
        snapshot: CockpitSnapshot(
          routeName: '/settings',
          diagnosticLevel: CockpitSnapshotProfile.investigate,
          visibleTargets: const <CockpitSnapshotTarget>[],
          network: CockpitNetworkSnapshot(
            totalEntryCount: 2,
            failureCount: 1,
            entries: <CockpitNetworkEntry>[
              CockpitNetworkEntry(
                requestId: 'net-2',
                method: 'POST',
                uri: 'http://127.0.0.1:44123/sync/submit',
                startedAt: DateTime.utc(2026, 3, 21, 8, 9, 59),
                durationMs: 180,
                statusCode: 503,
                error: 'Relay unavailable',
              ),
              CockpitNetworkEntry(
                requestId: 'net-1',
                method: 'GET',
                uri: 'http://127.0.0.1:44123/sync/health',
                startedAt: DateTime.utc(2026, 3, 21, 8, 9, 58),
                durationMs: 42,
                statusCode: 200,
              ),
            ],
          ),
        ),
      );

      final bundle = controller.finish(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
      );

      expect(bundle.acceptanceMarkdown, contains('## Network'));
      expect(bundle.acceptanceMarkdown, contains('Requests captured: 2'));
      expect(bundle.acceptanceMarkdown, contains('Failures: 1'));
      expect(
        bundle.acceptanceMarkdown,
        contains(
          'Latest request: POST http://127.0.0.1:44123/sync/submit · 503',
        ),
      );
      expect(
        bundle.acceptanceMarkdown,
        contains(
          'Latest failure: POST http://127.0.0.1:44123/sync/submit · 503',
        ),
      );
    },
  );

  test(
    'session bundle aggregates runtime activity from steps and snapshots',
    () {
      final timestamps = <DateTime>[
        DateTime.utc(2026, 3, 22, 9, 0, 0),
        DateTime.utc(2026, 3, 22, 9, 0, 1),
        DateTime.utc(2026, 3, 22, 9, 0, 2),
        DateTime.utc(2026, 3, 22, 9, 0, 5),
      ].iterator;

      DateTime nextTimestamp() {
        final didMove = timestamps.moveNext();
        if (!didMove) {
          throw StateError('No more timestamps available.');
        }
        return timestamps.current;
      }

      final controller = CockpitSessionController(
        sessionId: 'session-runtime-001',
        taskId: 'task-runtime',
        platform: 'android',
        now: nextTimestamp,
      );

      controller.recordStep(
        actionType: 'runtime_event',
        actionArgs: <String, Object?>{
          'eventId': 'runtime-1',
          'kind': CockpitRuntimeEventKind.flutterError.jsonValue,
          'severity': CockpitRuntimeEventSeverity.error.jsonValue,
          'message': 'setState() called after dispose()',
          'recordedAt': DateTime.utc(2026, 3, 22, 9, 0, 1).toIso8601String(),
        },
        observation: CockpitObservation(
          routeName: '/detail',
          phase: CockpitObservationPhase.failure,
        ),
      );

      controller.recordStep(
        actionType: 'collectSnapshot',
        actionArgs: const <String, Object?>{'profile': 'investigate'},
        snapshot: CockpitSnapshot(
          routeName: '/detail',
          diagnosticLevel: CockpitSnapshotProfile.investigate,
          runtime: CockpitRuntimeSnapshot(
            totalEntryCount: 2,
            errorCount: 1,
            warningCount: 1,
            entries: <CockpitRuntimeEvent>[
              CockpitRuntimeEvent(
                eventId: 'runtime-2',
                kind: CockpitRuntimeEventKind.debugLog,
                severity: CockpitRuntimeEventSeverity.info,
                message: 'sync completed',
                recordedAt: DateTime.utc(2026, 3, 22, 9, 0, 2),
              ),
            ],
            capturedEntryCount: 2,
          ),
        ),
      );

      final bundle = controller.finish(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
      );

      expect(bundle.manifest.runtimeEventCount, 2);
      expect(bundle.manifest.runtimeErrorCount, 1);
      expect(bundle.manifest.runtimeWarningCount, 1);
      expect(bundle.manifest.status, CockpitTaskStatus.failed);
      expect(
        bundle.manifest.failureSummary,
        'Runtime errors were captured during the task.',
      );
      expect(bundle.handoff['status'], 'failed');
      expect(bundle.handoff['runtimeErrorCount'], 1);
      expect(bundle.acceptanceMarkdown, contains('## Runtime'));
      expect(bundle.acceptanceMarkdown, contains('- Status: failed'));
      expect(bundle.acceptanceMarkdown, contains('Errors: 1'));
    },
  );

  test('CockpitContextBundle round-trips through json', () {
    final bundle = CockpitContextBundle(
      manifest: CockpitRunManifest(
        sessionId: 'session-003',
        taskId: 'task-home',
        platform: 'android',
        status: CockpitTaskStatus.completed,
        startedAt: DateTime.utc(2026, 3, 20, 8, 0, 0),
        finishedAt: DateTime.utc(2026, 3, 20, 8, 0, 3),
        artifactRefs: const [],
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: const [],
      observations: const [],
      acceptanceMarkdown: '# Acceptance\n\nDone.',
      handoff: const {'status': 'completed'},
    );

    expect(CockpitContextBundle.fromJson(bundle.toJson()), bundle);
  });
}
