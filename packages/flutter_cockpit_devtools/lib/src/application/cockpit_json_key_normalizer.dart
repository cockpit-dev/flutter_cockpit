Map<String, Object?> cockpitNormalizeJsonKeys(Map<String, Object?> json) {
  final normalized = <String, Object?>{};
  json.forEach((key, value) {
    final normalizedKey = _snakeToCamel(key);
    normalized[normalizedKey] = _normalizeJsonValue(normalizedKey, value);
  });
  return normalized;
}

Map<String, Object?> cockpitSnakeCaseJsonKeys(Map<String, Object?> json) {
  final normalized = <String, Object?>{};
  json.forEach((key, value) {
    final normalizedKey = _camelToSnake(key);
    normalized[normalizedKey] = _snakeCaseJsonValue(normalizedKey, value);
  });
  return normalized;
}

Object? cockpitSnakeCaseJsonValue(Object? value) {
  return _snakeCaseJsonValue(null, value);
}

String cockpitSnakeCaseEnumValue(String key, String value) {
  final normalized = _snakeCaseJsonValue(key, value);
  return normalized is String ? normalized : value;
}

Object? _normalizeJsonValue(String key, Object? value) {
  if (value is Map<Object?, Object?>) {
    return cockpitNormalizeJsonKeys(Map<String, Object?>.from(value));
  }
  if (value is List<Object?>) {
    return value
        .map((item) => _normalizeJsonValue(key, item))
        .toList(growable: false);
  }
  if (value is String && _enumLikeKeys.contains(key) && value.contains('_')) {
    return _snakeToCamel(value);
  }
  return value;
}

Object? _snakeCaseJsonValue(String? key, Object? value) {
  if (value is Map<Object?, Object?>) {
    return cockpitSnakeCaseJsonKeys(Map<String, Object?>.from(value));
  }
  if (value is List<Object?>) {
    return value
        .map((item) => _snakeCaseJsonValue(key, item))
        .toList(growable: false);
  }
  if (value is String &&
      key != null &&
      _enumLikeJsonKeys.contains(key) &&
      _looksLikeCamelEnum(value)) {
    return _camelToSnake(value);
  }
  return value;
}

String _snakeToCamel(String key) {
  if (!key.contains('_')) {
    return key;
  }
  final segments = key.split('_');
  if (segments.isEmpty) {
    return key;
  }
  return segments.first +
      segments.skip(1).map((segment) {
        if (segment.isEmpty) {
          return '';
        }
        return segment[0].toUpperCase() + segment.substring(1);
      }).join();
}

String _camelToSnake(String key) {
  if (key.isEmpty) {
    return key;
  }
  final buffer = StringBuffer();
  for (var index = 0; index < key.length; index += 1) {
    final rune = key.codeUnitAt(index);
    final isUppercase = rune >= 65 && rune <= 90;
    if (isUppercase) {
      if (index > 0) {
        buffer.write('_');
      }
      buffer.writeCharCode(rune + 32);
      continue;
    }
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

const Set<String> _enumLikeKeys = <String>{
  'commandType',
  'capturePolicy',
  'kind',
};

const Set<String> _enumLikeJsonKeys = <String>{
  'transport_type',
  'supported_commands',
  'supported_locator_strategies',
  'preferred_acceptance_recording_kind',
  'matched_kind',
  'command_type',
  'capture_policy',
  'recording_kind',
  'kind',
};

bool _looksLikeCamelEnum(String value) {
  return value.codeUnits.any((codeUnit) => codeUnit >= 65 && codeUnit <= 90);
}
