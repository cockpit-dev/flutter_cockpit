enum CockpitQualityFlag {
  experimental,
  simulatorOnly,
  realDeviceOnly,
  requiresAccessibility,
  requiresDeveloperMode,
  requiresBrowserDriver,
  requiresForegroundWindow;

  static CockpitQualityFlag fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
