enum CockpitCapturePolicy {
  none,
  afterAction,
  onFailure,
  afterActionAndFailure;

  static CockpitCapturePolicy fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
