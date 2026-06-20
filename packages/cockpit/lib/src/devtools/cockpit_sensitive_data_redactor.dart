final class CockpitSensitiveDataRedactor {
  const CockpitSensitiveDataRedactor();

  static const redactedValue = '[REDACTED]';

  static const List<String> _sensitiveKeyFragments = <String>[
    'authorization',
    'cookie',
    'password',
    'secret',
    'token',
    'credential',
    'apikey',
  ];

  Object? redact(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _isSensitiveKey(entry.key)
              ? redactedValue
              : redact(entry.value),
      };
    }
    if (value is List) {
      return value.map(redact).toList(growable: false);
    }
    if (value is Set) {
      return value.map(redact).toList(growable: false);
    }
    return value;
  }

  bool _isSensitiveKey(Object? key) {
    final normalized = key.toString().toLowerCase().replaceAll(
      RegExp('[^a-z0-9]'),
      '',
    );
    return _sensitiveKeyFragments.any(normalized.contains);
  }
}
