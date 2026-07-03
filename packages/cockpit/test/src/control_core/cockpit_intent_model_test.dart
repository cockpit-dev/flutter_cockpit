import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/control_core/cockpit_intent.dart';
import 'package:cockpit/src/control_core/cockpit_intent_action.dart';
import 'package:cockpit/src/control_core/cockpit_intent_subject.dart';
import 'package:test/test.dart';

void main() {
  test('tap intent preserves locator and execution policy', () {
    const locator = CockpitLocator(text: 'Submit');

    final intent = CockpitIntent.tap(
      locator: locator,
      executionPolicy: CockpitExecutionPolicy.preferFlutter,
    );

    expect(intent.subject, CockpitIntentSubject.surface);
    expect(intent.action, CockpitIntentAction.tap);
    expect(intent.locator, locator);
    expect(intent.executionPolicy, CockpitExecutionPolicy.preferFlutter);
  });

  test('command conversion maps capture screenshot into intent action', () {
    final intent = CockpitIntent.fromCommand(
      CockpitCommand(
        commandId: 'capture-home',
        commandType: CockpitCommandType.captureScreenshot,
      ),
    );

    expect(intent.action, CockpitIntentAction.captureScreenshot);
    expect(intent.subject, CockpitIntentSubject.surface);
  });
}
