enum CockpitRevealAlignment {
  nearest,
  start,
  center,
  end;

  static CockpitRevealAlignment fromJson(Object? json) {
    return values.byName(json! as String);
  }

  static CockpitRevealAlignment? tryParse(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    for (final candidate in values) {
      if (candidate.name == value) {
        return candidate;
      }
    }
    return null;
  }
}
