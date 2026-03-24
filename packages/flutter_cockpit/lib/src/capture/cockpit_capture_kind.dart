enum CockpitCaptureKind {
  flutterView,
  nativeAcceptance;

  static CockpitCaptureKind fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
