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
}
