import 'dart:collection';

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
    return _freezeJsonValue(value, path);
  }

  static Map<String, Object?> jsonObject(Object? value, String path) {
    final frozen = jsonValue(value, path);
    if (frozen is! Map<String, Object?>) {
      throw FormatException('Expected an object at $path.');
    }
    return frozen;
  }
}

Object? _freezeJsonValue(Object? value, String path) {
  final state = _JsonFreezeState();
  final root = _JsonResultSlot();
  final tasks = <_JsonFreezeTask>[
    _JsonVisitTask(
      value: value,
      path: _JsonPath.root(path),
      depth: 0,
      assign: root.assign,
    ),
  ];
  while (tasks.isNotEmpty) {
    tasks.removeLast().run(tasks, state);
  }
  return root.value;
}

typedef _JsonValueAssignment = void Function(Object? value);

sealed class _JsonFreezeTask {
  void run(List<_JsonFreezeTask> tasks, _JsonFreezeState state);
}

final class _JsonVisitTask implements _JsonFreezeTask {
  _JsonVisitTask({
    required this.value,
    required this.path,
    required this.depth,
    required this.assign,
  });

  final Object? value;
  final _JsonPath path;
  final int depth;
  final _JsonValueAssignment assign;

  @override
  void run(List<_JsonFreezeTask> tasks, _JsonFreezeState state) {
    if (depth > cockpitFoundationJsonMaximumDepth) {
      throw FormatException(
        'JSON nesting exceeds the limit at ${path.render()}.',
      );
    }
    state.countNode(path);

    final currentValue = value;
    if (currentValue == null ||
        currentValue is String ||
        currentValue is bool ||
        currentValue is int) {
      assign(currentValue);
      return;
    }
    if (currentValue is num) {
      if (!currentValue.isFinite) {
        throw FormatException(
          'Expected a finite JSON number at ${path.render()}.',
        );
      }
      assign(currentValue.toDouble());
      return;
    }
    if (currentValue is List<Object?>) {
      state.enterContainer(currentValue, path);
      tasks.add(
        _JsonListTask(
          source: currentValue,
          path: path,
          depth: depth,
          assign: assign,
        ),
      );
      return;
    }
    if (currentValue is Map<Object?, Object?>) {
      state.enterContainer(currentValue, path);
      tasks.add(
        _JsonMapTask(
          source: currentValue,
          path: path,
          depth: depth,
          assign: assign,
        ),
      );
      return;
    }
    throw FormatException('Expected a JSON value at ${path.render()}.');
  }
}

final class _JsonListTask implements _JsonFreezeTask {
  _JsonListTask({
    required this.source,
    required this.path,
    required this.depth,
    required this.assign,
  });

  final List<Object?> source;
  final List<Object?> result = <Object?>[];
  final _JsonPath path;
  final int depth;
  final _JsonValueAssignment assign;
  var _index = 0;

  @override
  void run(List<_JsonFreezeTask> tasks, _JsonFreezeState state) {
    if (_index >= source.length) {
      state.leaveContainer(source);
      assign(List<Object?>.unmodifiable(result));
      return;
    }
    final index = _index;
    _index += 1;
    tasks
      ..add(this)
      ..add(
        _JsonVisitTask(
          value: source[index],
          path: path.index(index),
          depth: depth + 1,
          assign: result.add,
        ),
      );
  }
}

final class _JsonMapTask implements _JsonFreezeTask {
  _JsonMapTask({
    required this.source,
    required this.path,
    required this.depth,
    required this.assign,
  }) : _entries = source.entries.iterator;

  final Map<Object?, Object?> source;
  final Iterator<MapEntry<Object?, Object?>> _entries;
  final Map<String, Object?> result = <String, Object?>{};
  final _JsonPath path;
  final int depth;
  final _JsonValueAssignment assign;

  @override
  void run(List<_JsonFreezeTask> tasks, _JsonFreezeState state) {
    if (!_entries.moveNext()) {
      state.leaveContainer(source);
      assign(Map<String, Object?>.unmodifiable(result));
      return;
    }
    final entry = _entries.current;
    final key = entry.key;
    if (key is! String) {
      throw FormatException('Expected a string key at ${path.render()}.');
    }
    tasks
      ..add(this)
      ..add(
        _JsonVisitTask(
          value: entry.value,
          path: path.key(key),
          depth: depth + 1,
          assign: (value) => result[key] = value,
        ),
      );
  }
}

final class _JsonResultSlot {
  Object? value;

  void assign(Object? value) {
    this.value = value;
  }
}

final class _JsonPath {
  const _JsonPath._({this.root, this.parent, this.segment});

  factory _JsonPath.root(String root) => _JsonPath._(root: root);

  final String? root;
  final _JsonPath? parent;
  final String? segment;

  _JsonPath index(int index) => _JsonPath._(parent: this, segment: '[$index]');

  _JsonPath key(String key) => _JsonPath._(parent: this, segment: '.$key');

  String render() {
    final segments = <String>[];
    var current = this;
    while (current.parent != null) {
      segments.add(current.segment!);
      current = current.parent!;
    }
    final result = StringBuffer(current.root!);
    for (var index = segments.length - 1; index >= 0; index -= 1) {
      result.write(segments[index]);
    }
    return result.toString();
  }
}

final class _JsonFreezeState {
  final Set<Object> _activeContainers = HashSet<Object>.identity();
  var _nodeCount = 0;

  void countNode(_JsonPath path) {
    _nodeCount += 1;
    if (_nodeCount > cockpitFoundationJsonMaximumNodes) {
      throw FormatException(
        'JSON node count exceeds the limit at ${path.render()}.',
      );
    }
  }

  void enterContainer(Object container, _JsonPath path) {
    if (!_activeContainers.add(container)) {
      throw FormatException(
        'JSON container cycle detected at ${path.render()}.',
      );
    }
  }

  void leaveContainer(Object container) {
    _activeContainers.remove(container);
  }
}
