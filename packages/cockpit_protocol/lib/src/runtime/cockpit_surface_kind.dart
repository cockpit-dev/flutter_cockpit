enum CockpitSurfaceKind {
  flutterSemantic,
  nativeUi,
  systemUi,
  desktopWindow,
  browserDom,
  deviceShell,
  hostShell;

  static CockpitSurfaceKind fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
