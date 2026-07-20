enum CockpitCaptureKind {
  flutterView,
  appNative,
  hostSystem,
  nativeAcceptance;

  static CockpitCaptureKind fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
