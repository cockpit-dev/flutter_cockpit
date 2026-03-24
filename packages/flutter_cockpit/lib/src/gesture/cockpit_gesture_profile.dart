enum CockpitGestureProfile {
  fast,
  userLike,
  precise;

  static CockpitGestureProfile? maybeFromJson(Object? json) {
    if (json == null) {
      return null;
    }
    if (json is CockpitGestureProfile) {
      return json;
    }
    if (json is String) {
      final normalized = json.trim();
      if (normalized.isEmpty) {
        return null;
      }
      for (final value in values) {
        if (value.name.toLowerCase() == normalized.toLowerCase()) {
          return value;
        }
      }
    }
    return null;
  }
}
