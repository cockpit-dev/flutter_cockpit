enum CockpitEvidenceCapability {
  flutterScreenshot,
  nativeScreenshot,
  windowCapture,
  screenRecording,
  appLogs,
  deviceLogs,
  runtimeErrors,
  crashReports,
  networkSignals,
  domSnapshot,
  windowTree;

  static CockpitEvidenceCapability fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
