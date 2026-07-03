enum CockpitPlaneKind {
  flutterSemanticPlane,
  nativeUiPlane,
  deviceSystemPlane,
  hostPlane;

  static CockpitPlaneKind fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
