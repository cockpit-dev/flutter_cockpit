import 'dart:convert';

import 'package:cockpit_protocol/cockpit_protocol.dart';

final class CockpitSuiteMatrixExpander {
  const CockpitSuiteMatrixExpander();

  List<Map<String, Object?>> expand(
    CockpitTestMatrix matrix, {
    required Iterable<String> selectedAxes,
  }) {
    final selected = selectedAxes.toList(growable: false)..sort();
    if (selected.isEmpty) return const <Map<String, Object?>>[{}];
    for (final axis in selected) {
      if (!matrix.axes.containsKey(axis)) {
        throw FormatException('Unknown matrix axis $axis.');
      }
    }

    var rows = <Map<String, Object?>>[const <String, Object?>{}];
    for (final axis in matrix.axes.keys.toList()..sort()) {
      final expanded = <Map<String, Object?>>[];
      for (final row in rows) {
        for (final value in matrix.axes[axis]!) {
          expanded.add(<String, Object?>{...row, axis: value});
        }
      }
      rows = expanded;
    }
    rows.removeWhere(
      (row) => matrix.exclude.any((excluded) => _matches(row, excluded)),
    );
    for (final included in matrix.include) {
      if (!rows.any((row) => _same(row, included))) {
        rows.add(Map<String, Object?>.from(included));
      }
    }

    final projected = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final row in rows) {
      final value = <String, Object?>{
        for (final axis in selected) axis: row[axis],
      };
      final key = _canonical(value);
      if (seen.add(key)) {
        projected.add(Map<String, Object?>.unmodifiable(value));
      }
    }
    if (projected.length > matrix.maxCombinations) {
      throw const FormatException('Projected matrix exceeds its bound.');
    }
    return List<Map<String, Object?>>.unmodifiable(projected);
  }
}

bool _matches(Map<String, Object?> row, Map<String, Object?> pattern) {
  return pattern.entries.every(
    (entry) => _canonical(row[entry.key]) == _canonical(entry.value),
  );
}

bool _same(Map<String, Object?> left, Map<String, Object?> right) =>
    _canonical(left) == _canonical(right);

String _canonical(Object? value) => jsonEncode(_sorted(value));

Object? _sorted(Object? value) => switch (value) {
  Map<Object?, Object?> map => <String, Object?>{
    for (final key in map.keys.cast<String>().toList()..sort())
      key: _sorted(map[key]),
  },
  List<Object?> list => list.map(_sorted).toList(growable: false),
  _ => value,
};
