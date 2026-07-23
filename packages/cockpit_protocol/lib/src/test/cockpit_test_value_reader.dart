import 'dart:convert';

final class CockpitTestValueReader {
  const CockpitTestValueReader._();

  static final RegExp _idPattern = RegExp(r'^[A-Za-z][A-Za-z0-9._-]{0,127}$');
  static final RegExp _extensionPattern = RegExp(
    r'^x-[A-Za-z0-9][A-Za-z0-9._-]*$',
  );

  static Map<String, Object?> object(Object? value, String path) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Expected an object at $path.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException('Expected a string key at $path.');
      }
      result[key] = entry.value;
    }
    return result;
  }

  static void keys(
    Map<String, Object?> json,
    Set<String> allowed,
    String path, {
    Set<String> required = const <String>{},
    bool allowExtensions = false,
  }) {
    for (final key in required) {
      if (!json.containsKey(key)) {
        throw FormatException('Missing required field $path.$key.');
      }
    }
    for (final key in json.keys) {
      if (allowed.contains(key)) {
        continue;
      }
      if (allowExtensions && _extensionPattern.hasMatch(key)) {
        jsonValue(json[key], '$path.$key');
        continue;
      }
      throw FormatException('Unknown field $path.$key.');
    }
  }

  static String string(
    Object? value,
    String path, {
    bool id = false,
    int? maximum,
  }) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Expected a non-empty string at $path.');
    }
    if (maximum != null && value.length > maximum) {
      throw FormatException(
        'Expected $path to be at most $maximum characters.',
      );
    }
    if (id && !_idPattern.hasMatch(value)) {
      throw FormatException('Invalid identifier "$value" at $path.');
    }
    return value;
  }

  static String? optionalString(Object? value, String path, {bool id = false}) {
    return value == null ? null : string(value, path, id: id);
  }

  static bool boolean(Object? value, String path) {
    if (value is! bool) {
      throw FormatException('Expected a boolean at $path.');
    }
    return value;
  }

  static int integer(Object? value, String path, {int? minimum, int? maximum}) {
    if (value is! int) {
      throw FormatException('Expected an integer at $path.');
    }
    if (minimum != null && value < minimum) {
      throw FormatException('Expected $path to be at least $minimum.');
    }
    if (maximum != null && value > maximum) {
      throw FormatException('Expected $path to be at most $maximum.');
    }
    return value;
  }

  static double number(Object? value, String path) {
    if (value is! num || !value.isFinite) {
      throw FormatException('Expected a finite number at $path.');
    }
    return value.toDouble();
  }

  static List<Object?> list(Object? value, String path) {
    if (value is! List<Object?>) {
      throw FormatException('Expected a list at $path.');
    }
    return value;
  }

  static List<String> strings(
    Object? value,
    String path, {
    bool id = false,
    bool unique = false,
  }) {
    final values = list(value, path);
    final result = <String>[];
    final seen = <String>{};
    for (var index = 0; index < values.length; index += 1) {
      final item = string(values[index], '$path[$index]', id: id);
      if (unique && !seen.add(item)) {
        throw FormatException('Duplicate value at $path[$index].');
      }
      result.add(item);
    }
    return List<String>.unmodifiable(result);
  }

  static DateTime dateTime(Object? value, String path) {
    final source = string(value, path);
    final result = DateTime.tryParse(source);
    if (result == null || !result.isUtc) {
      throw FormatException('Expected an ISO-8601 UTC timestamp at $path.');
    }
    return result.toUtc();
  }

  static T enumeration<T extends Enum>(
    Object? value,
    List<T> values,
    String path,
  ) {
    final name = string(value, path);
    for (final candidate in values) {
      if (candidate.name == name) {
        return candidate;
      }
    }
    throw FormatException(
      'Unsupported value "$name" at $path. Expected one of '
      '${values.map((value) => value.name).join(', ')}.',
    );
  }

  static Object? jsonValue(Object? value, String path) {
    if (value == null || value is String || value is bool || value is int) {
      return value;
    }
    if (value is double) {
      if (!value.isFinite) {
        throw FormatException('Expected a finite JSON number at $path.');
      }
      return value;
    }
    if (value is num) {
      final converted = value.toDouble();
      if (!converted.isFinite) {
        throw FormatException('Expected a finite JSON number at $path.');
      }
      return converted;
    }
    if (value is List<Object?>) {
      return List<Object?>.unmodifiable(<Object?>[
        for (var index = 0; index < value.length; index += 1)
          jsonValue(value[index], '$path[$index]'),
      ]);
    }
    if (value is Map<Object?, Object?>) {
      final map = object(value, path);
      return Map<String, Object?>.unmodifiable(<String, Object?>{
        for (final entry in map.entries)
          entry.key: jsonValue(entry.value, '$path.${entry.key}'),
      });
    }
    throw FormatException('Expected a JSON value at $path.');
  }

  static Map<String, Object?> extensions(
    Map<String, Object?> value,
    String path,
  ) {
    final copy = object(jsonValue(value, path), path);
    keys(copy, const <String>{}, path, allowExtensions: true);
    return Map<String, Object?>.unmodifiable(copy);
  }

  static String canonicalJson(Object? value) =>
      jsonEncode(jsonValue(value, r'$'));
}
