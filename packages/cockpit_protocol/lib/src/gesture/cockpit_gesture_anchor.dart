enum CockpitGestureAnchor {
  center,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  textHitTestable;

  static CockpitGestureAnchor maybeFromJson(Object? json) {
    if (json is CockpitGestureAnchor) {
      return json;
    }
    if (json is! String) {
      return CockpitGestureAnchor.center;
    }
    final normalized = json.trim();
    if (normalized.isEmpty) {
      return CockpitGestureAnchor.center;
    }
    for (final value in values) {
      if (value.name.toLowerCase() == normalized.toLowerCase()) {
        return value;
      }
    }
    return CockpitGestureAnchor.center;
  }
}
