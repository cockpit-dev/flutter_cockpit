String cockpitSortableTimestampToken(DateTime timestamp) {
  final utc = timestamp.toUtc();
  return [
    utc.year.toString().padLeft(4, '0'),
    utc.month.toString().padLeft(2, '0'),
    utc.day.toString().padLeft(2, '0'),
    'T',
    utc.hour.toString().padLeft(2, '0'),
    utc.minute.toString().padLeft(2, '0'),
    utc.second.toString().padLeft(2, '0'),
    utc.millisecond.toString().padLeft(3, '0'),
    utc.microsecond.toString().padLeft(3, '0'),
    'Z',
  ].join();
}

String cockpitSanitizeArtifactNameToken(
  String value, {
  required String fallback,
  bool lowercase = false,
}) {
  final source = lowercase ? value.toLowerCase() : value;
  final unsafePattern = lowercase
      ? RegExp(r'[^a-z0-9]+')
      : RegExp(r'[^A-Za-z0-9._-]+');
  final sanitized = source
      .trim()
      .replaceAll(unsafePattern, '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  if (sanitized.isNotEmpty) {
    return sanitized;
  }
  final fallbackSource = lowercase ? fallback.toLowerCase() : fallback;
  final sanitizedFallback = fallbackSource
      .trim()
      .replaceAll(unsafePattern, '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  return sanitizedFallback.isEmpty ? 'artifact' : sanitizedFallback;
}
