enum CockpitTaskStatus {
  running,
  completed,
  failed;

  static CockpitTaskStatus fromJson(Object? value) {
    return CockpitTaskStatus.values.byName(value! as String);
  }
}
