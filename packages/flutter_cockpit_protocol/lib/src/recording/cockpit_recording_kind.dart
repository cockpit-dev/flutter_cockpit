enum CockpitRecordingKind {
  nativeScreen;

  static CockpitRecordingKind fromJson(Object? json) {
    return values.firstWhere(
      (kind) => kind.name == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported recording kind.',
      ),
    );
  }
}
