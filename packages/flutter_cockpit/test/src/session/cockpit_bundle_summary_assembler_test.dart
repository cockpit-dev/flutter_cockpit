import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assembles a bundle summary with runtime-driven failure handoff', () {
    final assembler = CockpitBundleSummaryAssembler(
      now: () => DateTime.utc(2026, 3, 30, 10, 0, 5),
    );
    final bundle = assembler.assemble(
      session: CockpitSession(
        sessionId: 'session-runtime',
        taskId: 'task-runtime',
        platform: 'android',
        startedAt: DateTime.utc(2026, 3, 30, 10, 0, 0),
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'runtime_event',
          actionArgs: <String, Object?>{
            'eventId': 'runtime-1',
            'kind': CockpitRuntimeEventKind.flutterError.jsonValue,
            'severity': CockpitRuntimeEventSeverity.error.jsonValue,
            'message': 'setState() called after dispose()',
            'recordedAt': DateTime.utc(2026, 3, 30, 10, 0, 1).toIso8601String(),
          },
          observedAt: DateTime.utc(2026, 3, 30, 10, 0, 1),
          status: CockpitCommandStatus.failed,
        ),
      ],
      status: CockpitTaskStatus.completed,
      capabilitiesUsed: const <String>['tap'],
    );

    expect(bundle.manifest.status, CockpitTaskStatus.failed);
    expect(bundle.manifest.runtimeErrorCount, 1);
    expect(bundle.handoff['status'], 'failed');
    expect(bundle.acceptanceMarkdown, contains('## Runtime'));
  });

  test('bundle summary exposes planes used, target kind, and fallback count',
      () {
    final assembler = CockpitBundleSummaryAssembler(
      now: () => DateTime.utc(2026, 4, 11, 9, 5, 0),
    );
    final bundle = assembler.assemble(
      session: CockpitSession(
        sessionId: 'session-plane-aware',
        taskId: 'task-plane-aware',
        platform: 'android',
        startedAt: DateTime.utc(2026, 4, 11, 9, 0, 0),
      ),
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      steps: <CockpitStepRecord>[
        CockpitStepRecord(
          index: 0,
          actionType: 'captureScreenshot',
          actionArgs: const <String, Object?>{'commandId': 'baseline_capture'},
          observedAt: DateTime.utc(2026, 4, 11, 9, 0, 10),
          targetKind: CockpitTargetKind.flutterApp,
          executionPlane: CockpitPlaneKind.flutterSemanticPlane,
          surfaceKind: CockpitSurfaceKind.flutterSemantic,
          status: CockpitCommandStatus.succeeded,
        ),
        CockpitStepRecord(
          index: 1,
          actionType: 'tap',
          actionArgs: const <String, Object?>{'commandId': 'save'},
          observedAt: DateTime.utc(2026, 4, 11, 9, 0, 20),
          targetKind: CockpitTargetKind.flutterApp,
          executionPlane: CockpitPlaneKind.nativeUiPlane,
          surfaceKind: CockpitSurfaceKind.nativeUi,
          usedPlaneFallback: true,
          fallbackTrail: const <CockpitPlaneKind>[
            CockpitPlaneKind.flutterSemanticPlane,
          ],
          status: CockpitCommandStatus.succeeded,
        ),
      ],
      status: CockpitTaskStatus.completed,
      capabilitiesUsed: const <String>['tap', 'captureScreenshot'],
    );

    expect(bundle.manifest.targetKind, CockpitTargetKind.flutterApp);
    expect(
      bundle.manifest.primaryExecutionPlane,
      CockpitPlaneKind.flutterSemanticPlane,
    );
    expect(bundle.manifest.planesUsed, <CockpitPlaneKind>[
      CockpitPlaneKind.flutterSemanticPlane,
      CockpitPlaneKind.nativeUiPlane,
    ]);
    expect(bundle.manifest.surfaceKindsUsed, <CockpitSurfaceKind>[
      CockpitSurfaceKind.flutterSemantic,
      CockpitSurfaceKind.nativeUi,
    ]);
    expect(bundle.manifest.fallbackCount, 1);
    expect(bundle.handoff['targetKind'], 'flutterApp');
    expect(bundle.handoff['primaryExecutionPlane'], 'flutterSemanticPlane');
    expect(bundle.handoff['planesUsed'], <String>[
      'flutterSemanticPlane',
      'nativeUiPlane',
    ]);
    expect(bundle.handoff['surfaceKindsUsed'], <String>[
      'flutterSemantic',
      'nativeUi',
    ]);
    expect(bundle.handoff['fallbackCount'], 1);
    expect(
      (bundle.handoff['gates'] as Map<String, Object?>)['intendedPlaneWorked'],
      isFalse,
    );
    expect(
      (bundle.handoff['gates'] as Map<String, Object?>)['fallbackAcceptable'],
      isTrue,
    );
  });
}
