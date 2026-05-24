import 'package:flutter_cockpit/flutter_cockpit.dart';

CockpitCommand cockpitCommandWithAiEvidenceDefaults(CockpitCommand command) {
  if (!_shouldDefaultToAfterActionCapture(command)) {
    return command;
  }

  return command.copyWith(
    capturePolicy: CockpitCapturePolicy.afterAction,
    captureFailurePolicy: CockpitCaptureFailurePolicy.degradeCommand,
    screenshotRequest:
        command.screenshotRequest ??
        CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.afterAction,
          name: command.commandId,
          includeSnapshot: true,
          attachToStep: true,
          snapshotOptions: const CockpitSnapshotOptions.live(),
        ),
  );
}

bool cockpitCommandUsesAiEvidenceDefaults(CockpitCommand command) {
  return _shouldDefaultToAfterActionCapture(command);
}

bool cockpitCommandTypeIsAiEvidenceKeyOperation(
  CockpitCommandType commandType,
) {
  return _isKeyOperation(commandType);
}

bool _shouldDefaultToAfterActionCapture(CockpitCommand command) {
  if (command.commandType == CockpitCommandType.captureScreenshot ||
      command.commandType == CockpitCommandType.collectSnapshot) {
    return false;
  }
  if (command.capturePolicy != CockpitCapturePolicy.none) {
    return false;
  }
  if (command.screenshotRequest != null) {
    return _isKeyOperation(command.commandType);
  }
  return _isKeyOperation(command.commandType);
}

bool _isKeyOperation(CockpitCommandType commandType) {
  return switch (commandType) {
    CockpitCommandType.tap ||
    CockpitCommandType.enterText ||
    CockpitCommandType.focusTextInput ||
    CockpitCommandType.setTextEditingValue ||
    CockpitCommandType.sendTextInputAction ||
    CockpitCommandType.sendKeyEvent ||
    CockpitCommandType.sendKeyDownEvent ||
    CockpitCommandType.sendKeyUpEvent ||
    CockpitCommandType.longPress ||
    CockpitCommandType.doubleTap ||
    CockpitCommandType.drag ||
    CockpitCommandType.fling ||
    CockpitCommandType.swipe ||
    CockpitCommandType.pinchZoom ||
    CockpitCommandType.rotate ||
    CockpitCommandType.panZoom ||
    CockpitCommandType.multiTouch ||
    CockpitCommandType.scrollUntilVisible ||
    CockpitCommandType.back ||
    CockpitCommandType.showOnScreen ||
    CockpitCommandType.increase ||
    CockpitCommandType.decrease ||
    CockpitCommandType.dismiss => true,
    CockpitCommandType.clearNetworkActivity ||
    CockpitCommandType.waitForNetworkIdle ||
    CockpitCommandType.waitForUiIdle ||
    CockpitCommandType.waitFor ||
    CockpitCommandType.assertVisible ||
    CockpitCommandType.assertText ||
    CockpitCommandType.captureScreenshot ||
    CockpitCommandType.collectSnapshot => false,
  };
}
