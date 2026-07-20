enum CockpitExecutionPolicy {
  auto,
  preferFlutter,
  preferNative,
  preferSystem,
  forcePlane,
  noFallback;

  static CockpitExecutionPolicy fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
