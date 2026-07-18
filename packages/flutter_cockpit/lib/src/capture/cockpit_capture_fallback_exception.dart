final class CockpitCaptureFallbackException implements Exception {
  const CockpitCaptureFallbackException({
    required this.primaryError,
    required this.primaryStackTrace,
    required this.fallbackError,
    required this.fallbackStackTrace,
  });

  final Object primaryError;
  final StackTrace primaryStackTrace;
  final Object fallbackError;
  final StackTrace fallbackStackTrace;

  @override
  String toString() {
    return 'Screenshot capture failed at the primary source: $primaryError; '
        'fallback capture also failed: $fallbackError';
  }
}
