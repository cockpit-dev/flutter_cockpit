import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appends immutable step records with incrementing indexes', () {
    final timestamps = <DateTime>[
      DateTime.utc(2026, 3, 30, 10, 0, 0),
      DateTime.utc(2026, 3, 30, 10, 0, 1),
    ].iterator;
    final recorder = CockpitStepRecorder(
      now: () {
        timestamps.moveNext();
        return timestamps.current;
      },
      observationAssembler: const CockpitObservationAssembler(),
    );

    recorder.recordStep(
      actionType: 'tap',
      actionArgs: const <String, Object?>{'target': 'save_button'},
    );

    expect(recorder.steps, hasLength(1));
    expect(recorder.steps.single.index, 0);
    expect(recorder.steps.single.actionType, 'tap');
    expect(
      recorder.steps.single.observedAt,
      DateTime.utc(2026, 3, 30, 10, 0, 0),
    );
  });

  test('captures step_screenshot artifacts as capture evidence', () {
    final recorder = CockpitStepRecorder(
      now: () => DateTime.utc(2026, 3, 30, 10, 0, 0),
      observationAssembler: const CockpitObservationAssembler(),
    );

    recorder.recordCommandResult(
      CockpitCommand(
        commandId: 'cmd-capture',
        commandType: CockpitCommandType.captureScreenshot,
      ),
      CockpitCommandResult(
        success: true,
        commandId: 'cmd-capture',
        commandType: CockpitCommandType.captureScreenshot,
        durationMs: 12,
        artifacts: const <CockpitArtifactRef>[
          CockpitArtifactRef(
            role: 'screenshot',
            relativePath: 'screenshots/final.png',
          ),
          CockpitArtifactRef(
            role: 'step_screenshot',
            relativePath: 'screenshots/step_001.png',
          ),
          CockpitArtifactRef(
            role: 'diagnostics',
            relativePath: 'diagnostics/final.json',
          ),
        ],
      ),
    );

    final captureRefs = recorder.steps.single.captureRefs;
    expect(
      captureRefs.map((artifact) => artifact.relativePath),
      unorderedEquals(<String>[
        'screenshots/final.png',
        'screenshots/step_001.png',
      ]),
    );
  });
}
