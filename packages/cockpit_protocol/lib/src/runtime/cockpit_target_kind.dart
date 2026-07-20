enum CockpitTargetKind {
  flutterApp,
  nativeApp,
  desktopApp,
  browserPage,
  systemSurface,
  device,
  hostWorkspace;

  static CockpitTargetKind fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
