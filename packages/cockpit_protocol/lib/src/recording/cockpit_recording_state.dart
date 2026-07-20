enum CockpitRecordingState {
  idle,
  starting,
  recording,
  stopping,
  completed,
  failed;

  static CockpitRecordingState fromJson(Object? json) {
    return values.firstWhere(
      (state) => state.name == json,
      orElse: () => throw ArgumentError.value(
        json,
        'json',
        'Unsupported recording state.',
      ),
    );
  }
}
