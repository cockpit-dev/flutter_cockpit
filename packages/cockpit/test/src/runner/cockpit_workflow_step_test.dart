import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('parses and serializes workflow step descriptions', () {
    final script = cockpitControlScriptFromText('''
sessionId: described-session
taskId: described-task
platform: macos
steps:
  - stepId: open-settings
    stepType: command
    description: Open settings before checking sync configuration.
    command:
      commandId: tap-settings
      commandType: tap
      locator:
        text: Settings
  - stepId: dismiss-dialog-if-present
    stepType: if
    description: Dismiss an optional system dialog without failing the flow.
    condition:
      commandId: has-dialog
      commandType: assertText
      parameters:
        text: Allow
    thenSteps:
      - stepId: accept-dialog
        stepType: command
        description: Accept the optional dialog.
        command:
          commandId: tap-allow
          commandType: tap
          locator:
            text: Allow
''');

    final commandStep =
        script.workflowSteps.first as CockpitCommandWorkflowStep;
    expect(
      commandStep.description,
      'Open settings before checking sync configuration.',
    );
    expect(
      commandStep.toJson()['description'],
      'Open settings before checking sync configuration.',
    );

    final ifStep = script.workflowSteps.last as CockpitIfWorkflowStep;
    expect(
      ifStep.description,
      'Dismiss an optional system dialog without failing the flow.',
    );
    expect(
      (ifStep.thenSteps.single as CockpitCommandWorkflowStep).description,
      'Accept the optional dialog.',
    );
    expect(
      ((ifStep.toJson()['thenSteps']! as List<Object?>).single
          as Map<String, Object?>)['description'],
      'Accept the optional dialog.',
    );
  });

  test('rejects non-string workflow step descriptions', () {
    expect(
      () => CockpitWorkflowStep.fromJson(<String, Object?>{
        'stepType': 'command',
        'description': 42,
        'command': CockpitCommand(
          commandId: 'tap-settings',
          commandType: CockpitCommandType.tap,
        ).toJson(),
      }, path: 'steps[0]'),
      throwsFormatException,
    );
  });
}
