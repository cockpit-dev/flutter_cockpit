final class CockpitRegistryValueReader {
  const CockpitRegistryValueReader._();

  static Map<String, Object?> object(
    Object? value,
    String path,
    Set<String> fields,
  ) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Expected object at $path.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('Expected string key at $path.');
      }
      result[entry.key! as String] = entry.value;
    }
    for (final field in fields) {
      if (!result.containsKey(field)) {
        throw FormatException('Missing field $path.$field.');
      }
    }
    for (final field in result.keys) {
      if (!fields.contains(field)) {
        throw FormatException('Unknown field $path.$field.');
      }
    }
    return result;
  }

  static List<Object?> list(Object? value, String path) {
    if (value is! List<Object?>) {
      throw FormatException('Expected list at $path.');
    }
    return value;
  }

  static String string(Object? value, String path, {int maximum = 4096}) {
    if (value is! String || value.isEmpty || value.length > maximum) {
      throw FormatException('Expected bounded string at $path.');
    }
    return value;
  }

  static String id(Object? value, String path) {
    final result = string(value, path, maximum: 128);
    if (!_isAsciiLetter(result.codeUnitAt(0)) ||
        result.codeUnits
            .skip(1)
            .any(
              (value) =>
                  !_isAsciiLetter(value) &&
                  !_isAsciiDigit(value) &&
                  value != 0x2e &&
                  value != 0x5f &&
                  value != 0x2d,
            )) {
      throw FormatException('Invalid identifier at $path.');
    }
    return result;
  }

  static bool _isAsciiLetter(int value) =>
      (value >= 0x41 && value <= 0x5a) || (value >= 0x61 && value <= 0x7a);

  static bool _isAsciiDigit(int value) => value >= 0x30 && value <= 0x39;

  static bool boolean(Object? value, String path) {
    if (value is! bool) {
      throw FormatException('Expected boolean at $path.');
    }
    return value;
  }

  static int integer(Object? value, String path, {int maximum = 1000000}) {
    if (value is! int || value < 0 || value > maximum) {
      throw FormatException('Expected bounded integer at $path.');
    }
    return value;
  }

  static DateTime timestamp(Object? value, String path) {
    final source = string(value, path, maximum: 64);
    final parsed = DateTime.tryParse(source);
    if (parsed == null || !source.endsWith('Z') || !parsed.isUtc) {
      throw FormatException('Expected UTC timestamp at $path.');
    }
    return parsed.toUtc();
  }

  static E enumeration<E extends Enum>(
    Object? value,
    String path,
    List<E> values,
  ) {
    final source = string(value, path, maximum: 64);
    for (final candidate in values) {
      if (candidate.name == source) {
        return candidate;
      }
    }
    throw FormatException('Unknown enum value at $path.');
  }
}
