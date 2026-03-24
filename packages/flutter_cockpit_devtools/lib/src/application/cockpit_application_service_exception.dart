final class CockpitApplicationServiceException implements Exception {
  const CockpitApplicationServiceException({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final Map<String, Object?> details;

  @override
  String toString() {
    if (details.isEmpty) {
      return 'CockpitApplicationServiceException($code): $message';
    }
    return 'CockpitApplicationServiceException($code): $message $details';
  }
}
