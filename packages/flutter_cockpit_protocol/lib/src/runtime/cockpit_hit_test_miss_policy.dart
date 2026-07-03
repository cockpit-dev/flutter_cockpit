enum CockpitHitTestMissPolicy {
  ignore,
  warn,
  fail;

  static CockpitHitTestMissPolicy? maybeFromJson(Object? json) {
    if (json == null) {
      return null;
    }
    if (json is CockpitHitTestMissPolicy) {
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
