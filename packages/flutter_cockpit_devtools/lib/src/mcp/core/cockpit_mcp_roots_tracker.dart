import 'dart:async';

import 'package:dart_mcp/server.dart';

typedef CockpitMcpRootsReader = Future<List<Root>> Function();

final class CockpitMcpRootsTracker {
  CockpitMcpRootsTracker({this.forceFallback = false});

  final bool forceFallback;

  bool _clientSupportsRoots = false;
  final List<Root> _nativeRoots = <Root>[];
  final List<Root> _fallbackRoots = <Root>[];
  StreamSubscription<void>? _rootsChangedSubscription;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get onChanged => _changes.stream;

  bool get fallbackActive => forceFallback || !_clientSupportsRoots;

  bool get clientSupportsRoots => _clientSupportsRoots;

  List<Root> get effectiveRoots => List<Root>.unmodifiable(
        fallbackActive ? _fallbackRoots : _nativeRoots,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'clientSupportsRoots': clientSupportsRoots,
        'fallbackActive': fallbackActive,
        'roots': effectiveRoots
            .map(
              (root) => <String, Object?>{
                'uri': root.uri,
                if (root.name != null) 'name': root.name!,
              },
            )
            .toList(growable: false),
      };

  Future<void> bind({
    required bool clientSupportsRoots,
    required CockpitMcpRootsReader readRoots,
    Stream<void>? rootsChanged,
  }) async {
    await _rootsChangedSubscription?.cancel();
    _clientSupportsRoots = clientSupportsRoots;

    if (!fallbackActive) {
      await _refresh(readRoots);
      _rootsChangedSubscription = rootsChanged?.listen((_) {
        unawaited(_refresh(readRoots));
      });
      return;
    }

    _nativeRoots.clear();
    _changes.add(null);
  }

  void addFallbackRoots(Iterable<Root> roots) {
    if (!fallbackActive) {
      throw StateError('Fallback roots are not active.');
    }

    var changed = false;
    for (final root in roots) {
      final exists = _fallbackRoots.any((candidate) => candidate.uri == root.uri);
      if (!exists) {
        _fallbackRoots.add(root);
        changed = true;
      }
    }
    if (changed) {
      _changes.add(null);
    }
  }

  void removeFallbackRoots(Iterable<String> uris) {
    if (!fallbackActive) {
      throw StateError('Fallback roots are not active.');
    }

    final before = _fallbackRoots.length;
    _fallbackRoots.removeWhere((root) => uris.contains(root.uri));
    if (_fallbackRoots.length != before) {
      _changes.add(null);
    }
  }

  Future<void> dispose() async {
    await _rootsChangedSubscription?.cancel();
    await _changes.close();
  }

  Future<void> _refresh(CockpitMcpRootsReader readRoots) async {
    final roots = await readRoots();
    _nativeRoots
      ..clear()
      ..addAll(roots);
    _changes.add(null);
  }
}
