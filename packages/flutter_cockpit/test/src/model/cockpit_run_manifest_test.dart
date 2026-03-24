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
}
