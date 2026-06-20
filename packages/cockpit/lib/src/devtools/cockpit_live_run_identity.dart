String cockpitCreateLiveRunId(String sessionId, {DateTime? now}) {
  final timestamp = _timestampPrefix((now ?? DateTime.now()).toUtc());
  final suffix = _safeRunIdSegment(sessionId);
  return suffix.isEmpty ? timestamp : '${timestamp}_$suffix';
}

String _timestampPrefix(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  String three(int number) => number.toString().padLeft(3, '0');
  return '${value.year}${two(value.month)}${two(value.day)}T'
      '${two(value.hour)}${two(value.minute)}${two(value.second)}'
      '${three(value.millisecond)}${three(value.microsecond)}Z';
}

String _safeRunIdSegment(String value) {
  return value
      .replaceAll(RegExp('[^A-Za-z0-9._-]+'), '-')
      .replaceAll(RegExp('-+'), '-')
      .replaceAll(RegExp(r'^[._-]+'), '')
      .replaceAll(RegExp(r'[._-]+$'), '');
}
