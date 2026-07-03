enum CockpitCommandType {
  tap,
  enterText,
  focusTextInput,
  setTextEditingValue,
  sendTextInputAction,
  sendKeyEvent,
  sendKeyDownEvent,
  sendKeyUpEvent,
  longPress,
  doubleTap,
  drag,
  fling,
  swipe,
  pinchZoom,
  rotate,
  panZoom,
  multiTouch,
  scrollUntilVisible,
  clearNetworkActivity,
  waitForNetworkIdle,
  waitForUiIdle,
  back,
  showOnScreen,
  increase,
  decrease,
  dismiss,
  dismissKeyboard,
  waitFor,
  assertVisible,
  assertText,
  captureScreenshot,
  collectSnapshot;

  static CockpitCommandType fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
