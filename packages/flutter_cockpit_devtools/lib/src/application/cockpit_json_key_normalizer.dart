import 'dart:convert';

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
