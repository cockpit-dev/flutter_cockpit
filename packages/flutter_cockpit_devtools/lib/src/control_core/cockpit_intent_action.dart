import 'package:flutter_cockpit/flutter_cockpit.dart';

enum CockpitIntentAction {
  tap,
  enterText,
  captureScreenshot,
  collectSnapshot,
  waitFor,
  assertVisible,
  assertText,
  runShell;

  static CockpitIntentAction fromCommandType(CockpitCommandType commandType) {
    return switch (commandType) {
      CockpitCommandType.tap => CockpitIntentAction.tap,
      CockpitCommandType.enterText => CockpitIntentAction.enterText,
      CockpitCommandType.captureScreenshot =>
        CockpitIntentAction.captureScreenshot,
      CockpitCommandType.collectSnapshot => CockpitIntentAction.collectSnapshot,
      CockpitCommandType.waitFor => CockpitIntentAction.waitFor,
      CockpitCommandType.assertVisible => CockpitIntentAction.assertVisible,
      CockpitCommandType.assertText => CockpitIntentAction.assertText,
      _ => throw UnsupportedError(
          'CockpitIntentAction does not yet support ${commandType.name}.',
        ),
    };
  }
}
