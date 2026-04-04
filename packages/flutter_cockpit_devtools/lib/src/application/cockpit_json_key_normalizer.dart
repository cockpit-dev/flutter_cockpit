import 'dart:convert';

Map<String, Object?> cockpitNormalizeJsonKeys(Map<String, Object?> json) {
  return cockpitCamelCaseJsonKeys(json);
}

Map<String, Object?> cockpitCamelCaseJsonKeys(Map<String, Object?> json) {
  final normalized = <String, Object?>{};
  json.forEach((key, value) {
    final normalizedKey = _snakeToCamel(key);
    final normalizedValue = _camelCaseJsonValue(normalizedKey, value);
    if (normalizedValue != null) {
      normalized[normalizedKey] = normalizedValue;
    }
  });
  return normalized;
}

Object? cockpitCamelCaseJsonValue(Object? value) {
  return _camelCaseJsonValue(null, value);
}

Object? cockpitCompactJsonValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    final compacted = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        continue;
      }
      final compactedValue = cockpitCompactJsonValue(entry.value);
      if (compactedValue != null) {
        compacted[key] = compactedValue;
      }
    }
    return compacted;
  }
  if (value is List<Object?>) {
    return value.map(cockpitCompactJsonValue).toList(growable: false);
  }
  return value;
}

String cockpitPrettyJsonText(Object? value) {
  return const JsonEncoder.withIndent(
    '  ',
  ).convert(cockpitCompactJsonValue(value));
}

String cockpitCompactJsonText(Object? value) {
  return jsonEncode(cockpitCompactJsonValue(value));
}

Object? _camelCaseJsonValue(String? key, Object? value) {
  if (value is Map<Object?, Object?>) {
    return cockpitCamelCaseJsonKeys(Map<String, Object?>.from(value));
  }
  if (value is List<Object?>) {
    if (key != null && _schemaFieldListKeys.contains(key)) {
      return value
          .map((item) => item is String ? _snakeToCamel(item) : item)
          .toList(growable: false);
    }
    return value
        .map((item) => _camelCaseJsonValue(key, item))
        .toList(growable: false);
  }
  if (value is String &&
      key != null &&
      _enumLikeKeys.contains(key) &&
      value.contains('_')) {
    return _snakeToCamel(value);
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

const Set<String> _enumLikeKeys = <String>{
  'commandType',
  'capturePolicy',
  'kind',
};

const Set<String> _schemaFieldListKeys = <String>{
  'required',
};
