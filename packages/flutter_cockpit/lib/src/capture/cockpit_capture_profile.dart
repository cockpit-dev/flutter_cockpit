enum CockpitCaptureProfile {
  diagnostic,
  acceptance,
  flutterPreferred,
  nativePreferred;

  static CockpitCaptureProfile fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
