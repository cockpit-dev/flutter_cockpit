import 'dart:collection';
import 'dart:convert';

import 'cockpit_decode_policy.dart';
import 'cockpit_foundation_constraints.dart';

final class CockpitFoundationValueReader {
  const CockpitFoundationValueReader._();

  static final RegExp _idPattern = RegExp(r'^[A-Za-z][A-Za-z0-9._-]{0,127}$');
  static final RegExp _kindPattern = RegExp(
    r'^[a-z][A-Za-z0-9]*(?:\.[a-z][A-Za-z0-9]*)+$',
  );
  static final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');
  static final RegExp _mediaTypePattern = RegExp(
    r'^[a-z0-9!#$&^_.+-]+/[a-z0-9!#$&^_.+-]+$',
  );
  static final RegExp _absolutePathPattern = RegExp(
    cockpitFoundationAbsolutePathPattern,
  );

  static Map<String, Object?> object(Object? value, String path) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Expected an object at $path.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw FormatException('Expected a string key at $path.');
      }
      result[entry.key! as String] = entry.value;
    }
    return result;
  }

  static void keys(
    Map<String, Object?> json,
    Set<String> allowed,
    String path, {
    Set<String> required = const <String>{},
    CockpitDecodePolicy policy = CockpitDecodePolicy.requests,
  }) {
    for (final key in required) {
      if (!json.containsKey(key)) {
        throw FormatException('Missing required field $path.$key.');
      }
    }
    if (policy.allowUnknownFields) {
      return;
    }
    for (final key in json.keys) {
      if (!allowed.contains(key)) {
        throw FormatException('Unknown field $path.$key.');
      }
    }
  }

  static String string(Object? value, String path, {int maximum = 4096}) {
    if (value is! String || value.trim().isEmpty || value.length > maximum) {
      throw FormatException('Expected a bounded non-empty string at $path.');
    }
    return value;
  }

  static String boundedString(
    Object? value,
    String path, {
    int maximum = 4096,
  }) {
    if (value is! String || value.length > maximum) {
      throw FormatException('Expected a bounded string at $path.');
    }
    return value;
  }

  static String? optionalString(
    Object? value,
    String path, {
    int maximum = 4096,
  }) => value == null ? null : string(value, path, maximum: maximum);

  static String id(Object? value, String path) {
    final result = string(value, path, maximum: 128);
    if (!_idPattern.hasMatch(result)) {
      throw FormatException('Invalid identifier "$result" at $path.');
    }
    return result;
  }

  static String kind(Object? value, String path) {
    final result = string(value, path, maximum: 128);
    if (!_kindPattern.hasMatch(result)) {
      throw FormatException('Invalid kind "$result" at $path.');
    }
    return result;
  }

  static String sha256(Object? value, String path) {
    final result = string(value, path, maximum: 64);
    if (!_sha256Pattern.hasMatch(result)) {
      throw FormatException('Expected a lowercase SHA-256 digest at $path.');
    }
    return result;
  }

  static String mediaType(Object? value, String path) {
    final result = string(value, path, maximum: 127);
    if (!_mediaTypePattern.hasMatch(result)) {
      throw FormatException('Invalid media type "$result" at $path.');
    }
    return result;
  }

  static String relativePath(Object? value, String path) {
    final result = string(value, path, maximum: 4096);
    final segments = result.split('/');
    if (result.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(result) ||
        result.contains(r'\') ||
        segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
      throw FormatException('Expected a confined relative path at $path.');
    }
    return result;
  }

  static String absolutePath(Object? value, String path) {
    final result = string(value, path, maximum: 4096);
    if (!_absolutePathPattern.hasMatch(result)) {
      throw FormatException('Expected a canonical absolute path at $path.');
    }
    return result;
  }

  static String opaqueToken(Object? value, String path) {
    final result = string(value, path, maximum: 512);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(result)) {
      throw FormatException('Expected an opaque base64url token at $path.');
    }
    return result;
  }

  static String apiPath(Object? value, String path) {
    final result = string(value, path, maximum: 4096);
    final uri = Uri.tryParse(result);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        !uri.path.startsWith('/api/v2/')) {
      throw FormatException('Expected a relative /api/v2 path at $path.');
    }
    return result;
  }

  static String apiTemplate(Object? value, String path) {
    final result = string(value, path, maximum: 4096);
    if (!result.startsWith('/api/v2/')) {
      throw FormatException('Expected a /api/v2 URI template at $path.');
    }
    return result;
  }

  static String schemaReference(Object? value, String path) {
    final result = string(value, path, maximum: 1024);
    final uri = Uri.tryParse(result);
    if (uri == null ||
        (!result.startsWith('#/\$defs/') && !result.contains('#/\$defs/'))) {
      throw FormatException('Expected a JSON Schema definition ref at $path.');
    }
    return result;
  }

  static bool boolean(Object? value, String path) {
    if (value is! bool) {
      throw FormatException('Expected a boolean at $path.');
    }
    return value;
  }

  static int integer(Object? value, String path, {int? min, int? max}) {
    if (value is! int ||
        (min != null && value < min) ||
        (max != null && value > max)) {
      throw FormatException('Expected a bounded integer at $path.');
    }
    return value;
  }

  static DateTime dateTime(Object? value, String path) {
    final source = string(value, path, maximum: 64);
    final parsed = DateTime.tryParse(source);
    if (!source.endsWith('Z') || parsed == null || !parsed.isUtc) {
      throw FormatException('Expected an ISO-8601 UTC timestamp at $path.');
    }
    return parsed.toUtc();
  }

  static DateTime utcDateTime(DateTime value, String path) {
    if (!value.isUtc) {
      throw FormatException('Expected a UTC DateTime at $path.');
    }
    return value;
  }

  static List<Object?> list(Object? value, String path) {
    if (value is! List<Object?>) {
      throw FormatException('Expected a list at $path.');
    }
    return value;
  }

  static List<String> ids(Object? value, String path) {
    final raw = list(value, path);
    final result = <String>[];
    final seen = <String>{};
    for (var index = 0; index < raw.length; index += 1) {
      final item = id(raw[index], '$path[$index]');
      if (!seen.add(item)) {
        throw FormatException('Duplicate identifier at $path[$index].');
      }
      result.add(item);
    }
    return List<String>.unmodifiable(result);
  }

  static Object? jsonValue(Object? value, String path) {
    return _freezeJsonValue(value, path, 0, _JsonFreezeState());
  }

  static Map<String, Object?> jsonObject(Object? value, String path) {
    final frozen = jsonValue(value, path);
    if (frozen is! Map<String, Object?>) {
      throw FormatException('Expected an object at $path.');
    }
    return frozen;
  }

  static String canonicalJson(Object? value) =>
      jsonEncode(jsonValue(value, r'$'));
}

Object? _freezeJsonValue(
  Object? value,
  String path,
  int depth,
  _JsonFreezeState state,
) {
  if (depth > cockpitFoundationJsonMaximumDepth) {
    throw FormatException('JSON nesting exceeds the limit at $path.');
  }
  state.countNode(path);

  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is num) {
    if (!value.isFinite) {
      throw FormatException('Expected a finite JSON number at $path.');
    }
    return value.toDouble();
  }
  if (value is List<Object?>) {
    state.enterContainer(value, path);
    try {
      return List<Object?>.unmodifiable(<Object?>[
        for (var index = 0; index < value.length; index += 1)
          _freezeJsonValue(value[index], '$path[$index]', depth + 1, state),
      ]);
    } finally {
      state.leaveContainer(value);
    }
  }
  if (value is Map<Object?, Object?>) {
    state.enterContainer(value, path);
    try {
      final map = CockpitFoundationValueReader.object(value, path);
      return Map<String, Object?>.unmodifiable(<String, Object?>{
        for (final entry in map.entries)
          entry.key: _freezeJsonValue(
            entry.value,
            '$path.${entry.key}',
            depth + 1,
            state,
          ),
      });
    } finally {
      state.leaveContainer(value);
    }
  }
  throw FormatException('Expected a JSON value at $path.');
}

final class _JsonFreezeState {
  final Set<Object> _activeContainers = HashSet<Object>.identity();
  var _nodeCount = 0;

  void countNode(String path) {
    _nodeCount += 1;
    if (_nodeCount > cockpitFoundationJsonMaximumNodes) {
      throw FormatException('JSON node count exceeds the limit at $path.');
    }
  }

  void enterContainer(Object container, String path) {
    if (!_activeContainers.add(container)) {
      throw FormatException('JSON container cycle detected at $path.');
    }
  }

  void leaveContainer(Object container) {
    _activeContainers.remove(container);
  }
}
