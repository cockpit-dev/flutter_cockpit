enum CockpitCommandStatus {
  succeeded,
  failed;

  static CockpitCommandStatus fromJson(Object? json) {
    return values.byName(json! as String);
  }
}
