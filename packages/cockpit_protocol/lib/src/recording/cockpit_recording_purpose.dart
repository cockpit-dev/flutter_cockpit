enum CockpitRecordingPurpose {
  acceptance,
  repro;

  static CockpitRecordingPurpose fromJson(Object? json) {
    final normalized = '$json'.trim().toLowerCase();
    switch (normalized) {
      case 'acceptance':
        return CockpitRecordingPurpose.acceptance;
      case 'repro':
      case 'diagnostic':
      case 'debug':
      case 'investigation':
        return CockpitRecordingPurpose.repro;
    }
    return values.firstWhere(
      (purpose) => purpose.name == normalized,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported recording purpose.',
      ),
    );
  }
}
