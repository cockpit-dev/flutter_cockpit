import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';

Map<String, Object?> cockpitReadConfigFile({
  required String path,
  required String label,
  required String usage,
}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw UsageException('$label file does not exist: $path', usage);
  }

  try {
    return cockpitConfigMapFromText(file.readAsStringSync(), label: label);
  } on FormatException catch (error) {
    throw FormatException('$label file is invalid: ${error.message}');
  }
}

Map<String, Object?> cockpitConfigMapFromText(
  String source, {
  required String label,
}) {
  final text = source.trimLeft();
  final Object? decoded;
  if (text.startsWith('{')) {
    decoded = jsonDecode(source);
  } else {
    decoded = loadYaml(source);
  }
  if (decoded is! Map<Object?, Object?>) {
    throw FormatException('$label must decode to an object.');
  }
  return _stringKeyedMap(decoded, label);
}

Map<String, Object?> _stringKeyedMap(Map<Object?, Object?> value, String path) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String || key.isEmpty) {
      throw FormatException('Object keys at $path must be non-empty strings.');
    }
    result[key] = _normalizeConfigValue(entry.value, '$path.$key');
  }
  return result;
}

Object? _normalizeConfigValue(Object? value, String path) {
  if (value is YamlMap || value is Map<Object?, Object?>) {
    return _stringKeyedMap(value as Map<Object?, Object?>, path);
  }
  if (value is YamlList || value is List<Object?>) {
    return (value as List<Object?>)
        .map((item) => _normalizeConfigValue(item, path))
        .toList(growable: false);
  }
  return value;
}
