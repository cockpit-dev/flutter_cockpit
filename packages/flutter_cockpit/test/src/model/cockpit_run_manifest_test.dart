import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CockpitRunManifest round-trips through json', () {
    final manifest = CockpitRunManifest(
      sessionId: 'session-001',
      taskId: 'task-login',
      platform: 'android',
      status: CockpitTaskStatus.completed,
      startedAt: DateTime.utc(2026, 3, 20, 8),
      finishedAt: DateTime.utc(2026, 3, 20, 8, 5),
      artifactRefs: const [
        CockpitArtifactRef(
          role: 'screenshot',
          relativePath: 'screenshots/step-01.png',
        ),
      ],
    );

    expect(CockpitRunManifest.fromJson(manifest.toJson()), manifest);
  });

  test('CockpitStepRecord preserves nested observation and artifacts', () {
    final record = CockpitStepRecord(
      index: 1,
      actionType: 'tap',
      actionArgs: const {'target': 'submit_button'},
      observedAt: DateTime.utc(2026, 3, 20, 8, 2),
      observation: CockpitObservation(
        routeName: '/login',
        interactiveElements: ['submit_button'],
      ),
      artifactRefs: const [
        CockpitArtifactRef(
          role: 'screenshot',
          relativePath: 'screenshots/step-02.png',
        ),
      ],
    );

    expect(CockpitStepRecord.fromJson(record.toJson()), record);
  });

  test('plane-aware manifest, observation, and step metadata round-trip', () {
    final manifest = CockpitRunManifest(
      sessionId: 'session-plane-aware',
      taskId: 'task-plane-aware',
      platform: 'android',
      status: CockpitTaskStatus.completed,
      startedAt: DateTime.utc(2026, 4, 11, 9, 0),
      finishedAt: DateTime.utc(2026, 4, 11, 9, 2),
      targetKind: CockpitTargetKind.flutterApp,
      primaryExecutionPlane: CockpitPlaneKind.flutterSemanticPlane,
      planesUsed: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.nativeUiPlane,
      ],
      surfaceKindsUsed: const <CockpitSurfaceKind>[
        CockpitSurfaceKind.flutterSemantic,
        CockpitSurfaceKind.nativeUi,
      ],
      fallbackCount: 1,
    );

    expect(CockpitRunManifest.fromJson(manifest.toJson()), manifest);
    expect(manifest.toJson(), containsPair('targetKind', 'flutterApp'));
    expect(
      manifest.toJson(),
      containsPair('primaryExecutionPlane', 'flutterSemanticPlane'),
    );
    expect(
      manifest.toJson(),
      containsPair(
        'planesUsed',
        <String>['flutterSemanticPlane', 'nativeUiPlane'],
      ),
    );
    expect(
      manifest.toJson(),
      containsPair(
        'surfaceKindsUsed',
        <String>['flutterSemantic', 'nativeUi'],
      ),
    );
    expect(manifest.toJson(), containsPair('fallbackCount', 1));

    final record = CockpitStepRecord(
      index: 2,
      actionType: 'tap',
      actionArgs: const <String, Object?>{'target': 'save_button'},
      observedAt: DateTime.utc(2026, 4, 11, 9, 1),
      targetKind: CockpitTargetKind.flutterApp,
      executionPlane: CockpitPlaneKind.nativeUiPlane,
      surfaceKind: CockpitSurfaceKind.nativeUi,
      usedPlaneFallback: true,
      fallbackTrail: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
      ],
      observation: CockpitObservation(
        routeName: '/editor',
        interactiveElements: const <String>['save_button'],
        targetKind: CockpitTargetKind.flutterApp,
        executionPlane: CockpitPlaneKind.nativeUiPlane,
        surfaceKind: CockpitSurfaceKind.nativeUi,
        fallbackUsed: true,
      ),
    );

    expect(CockpitStepRecord.fromJson(record.toJson()), record);
    expect(record.toJson(), containsPair('targetKind', 'flutterApp'));
    expect(
      record.toJson(),
      containsPair('executionPlane', 'nativeUiPlane'),
    );
    expect(record.toJson(), containsPair('surfaceKind', 'nativeUi'));
    expect(record.toJson(), containsPair('usedPlaneFallback', isTrue));
    expect(
      record.toJson(),
      containsPair('fallbackTrail', <String>['flutterSemanticPlane']),
    );
    expect(
      record.observation!.toJson(),
      containsPair('executionPlane', 'nativeUiPlane'),
    );
    expect(
      record.observation!.toJson(),
      containsPair('fallbackUsed', isTrue),
    );
  });
}
