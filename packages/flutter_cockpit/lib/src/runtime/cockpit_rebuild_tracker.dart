// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart' show TextField;
import 'package:flutter/widgets.dart'
    show
        EditableText,
        Element,
        Key,
        ObjectKey,
        RichText,
        Semantics,
        Text,
        ValueKey,
        Widget;

import 'cockpit_build_owner.dart';
import 'cockpit_rebuild_models.dart';
import 'cockpit_runtime_tree_visibility.dart';

final class CockpitRebuildTracker {
  CockpitRebuildTracker({
    required String Function() routeNameProvider,
    this.maxTrackedEntries = 120,
  }) : _routeNameProvider = routeNameProvider {
    _buildOwner = CockpitBuildOwner(onRebuildDirtyWidget: _recordRebuild);
    _buildOwner.attach();
  }

  final String Function() _routeNameProvider;
  final int maxTrackedEntries;
  late CockpitBuildOwner _buildOwner;
  final Map<String, _MutableRebuildEntry> _entries =
      <String, _MutableRebuildEntry>{};
  int _totalRebuildCount = 0;

  CockpitRebuildSnapshot snapshot({int maxEntries = 8}) {
    final sortedEntries = _entries.values.toList(growable: false)
      ..sort((left, right) {
        final rebuildCompare = right.rebuildCount.compareTo(left.rebuildCount);
        if (rebuildCompare != 0) {
          return rebuildCompare;
        }
        return left.signature.compareTo(right.signature);
      });
    final boundedEntries = sortedEntries
        .take(maxEntries)
        .map((entry) => entry.freeze())
        .toList(growable: false);
    return CockpitRebuildSnapshot(
      totalRebuildCount: _totalRebuildCount,
      uniqueElementCount: _entries.length,
      capturedEntryCount: boundedEntries.length,
      truncated: sortedEntries.length > boundedEntries.length,
      entries: boundedEntries,
    );
  }

  void clear() {
    _entries.clear();
    _totalRebuildCount = 0;
  }

  void dispose() {
    _buildOwner.dispose();
  }

  void _recordRebuild(Element element, bool builtOnce) {
    final entry = _resolveEntry(element);
    _totalRebuildCount += 1;

    final existing = _entries[entry.signature];
    if (existing != null) {
      existing.rebuildCount += 1;
      if (builtOnce) {
        existing.builtOnceCount += 1;
      }
      return;
    }

    if (_entries.length >= maxTrackedEntries) {
      final leastHotKey = _entries.entries
          .reduce(
            (left, right) => left.value.rebuildCount <= right.value.rebuildCount
                ? left
                : right,
          )
          .key;
      _entries.remove(leastHotKey);
    }

    _entries[entry.signature] = _MutableRebuildEntry(
      signature: entry.signature,
      routeName: entry.routeName,
      typeName: entry.typeName,
      keyValue: entry.keyValue,
      semanticId: entry.semanticId,
      textPreview: entry.textPreview,
      rebuildCount: 1,
      builtOnceCount: builtOnce ? 1 : 0,
    );
  }

  CockpitRebuildEntry _resolveEntry(Element element) {
    final routeName = cockpitResolvedElementRouteName(
          element,
          fallbackRouteName: _routeNameProvider(),
        ) ??
        _routeNameProvider();
    final widget = element.widget;
    final typeName = widget.runtimeType.toString();
    final keyValue = _keyValue(widget.key);
    final semanticId = widget is Semantics
        ? _firstNonEmpty(<String?>[
            _normalizeText(widget.properties.identifier),
            _normalizeText(widget.properties.label),
            _normalizeText(widget.properties.hint),
          ])
        : null;
    final textPreview = _textPreviewForWidget(widget);
    final signature = <String>[
      routeName,
      typeName,
      keyValue ?? '',
      semanticId ?? '',
      textPreview ?? '',
    ].join('|');
    return CockpitRebuildEntry(
      signature: signature,
      routeName: routeName,
      typeName: typeName,
      keyValue: keyValue,
      semanticId: semanticId,
      textPreview: textPreview,
      rebuildCount: 0,
      builtOnceCount: 0,
    );
  }

  String? _keyValue(Key? key) {
    final value = switch (key) {
      ValueKey<Object?>(value: final value) => _normalizeText(
          value?.toString(),
        ),
      ObjectKey(value: final value) => _normalizeText(value.toString()),
      _ => null,
    };
    if (value == null || value.startsWith('_')) {
      return null;
    }
    return value;
  }

  String? _textPreviewForWidget(Widget widget) {
    if (widget is Text) {
      return _normalizeText(widget.data ?? widget.textSpan?.toPlainText());
    }
    if (widget is RichText) {
      return _normalizeText(widget.text.toPlainText());
    }
    if (widget is EditableText) {
      return _normalizeText(widget.controller.text);
    }
    if (widget is TextField) {
      return _normalizeText(
        widget.controller?.text.isNotEmpty == true
            ? widget.controller?.text
            : widget.decoration?.labelText ?? widget.decoration?.hintText,
      );
    }
    return null;
  }

  String? _firstNonEmpty(List<String?> candidates) {
    for (final candidate in candidates) {
      final normalized = _normalizeText(candidate);
      if (normalized != null) {
        return normalized;
      }
    }
    return null;
  }

  String? _normalizeText(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }
}

final class _MutableRebuildEntry {
  _MutableRebuildEntry({
    required this.signature,
    required this.routeName,
    required this.typeName,
    required this.keyValue,
    required this.semanticId,
    required this.textPreview,
    required this.rebuildCount,
    required this.builtOnceCount,
  });

  final String signature;
  final String routeName;
  final String typeName;
  final String? keyValue;
  final String? semanticId;
  final String? textPreview;
  int rebuildCount;
  int builtOnceCount;

  CockpitRebuildEntry freeze() {
    return CockpitRebuildEntry(
      signature: signature,
      routeName: routeName,
      typeName: typeName,
      keyValue: keyValue,
      semanticId: semanticId,
      textPreview: textPreview,
      rebuildCount: rebuildCount,
      builtOnceCount: builtOnceCount,
    );
  }
}
