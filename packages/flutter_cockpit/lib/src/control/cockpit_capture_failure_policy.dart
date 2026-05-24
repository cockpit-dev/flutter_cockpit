enum CockpitCaptureFailurePolicy {
  failCommand,
  degradeCommand;

  static CockpitCaptureFailurePolicy fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
