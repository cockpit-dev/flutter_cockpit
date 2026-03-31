// ignore_for_file: deprecated_member_use

import 'dart:collection';

import '../control/cockpit_locator.dart';
import '../control/cockpit_locator_resolution.dart';
import '../errors/cockpit_command_error.dart';
import 'cockpit_snapshot.dart';
import 'cockpit_target.dart';
import 'cockpit_target_geometry.dart';

typedef CockpitDiscoveredTargetsProvider = List<CockpitTarget> Function();

final class CockpitTargetResolutionResult {
  const CockpitTargetResolutionResult._({
    this.target,
    this.locatorResolution,
    this.error,
    this.matches = const <CockpitTarget>[],
  });

  const CockpitTargetResolutionResult.success({
    required CockpitTarget target,
    required CockpitLocatorResolution locatorResolution,
    List<CockpitTarget> matches = const <CockpitTarget>[],
  }) : this._(
          target: target,
          locatorResolution: locatorResolution,
          matches: matches,
        );

  const CockpitTargetResolutionResult.failure({
    required CockpitCommandError error,
    List<CockpitTarget> matches = const <CockpitTarget>[],
  }) : this._(error: error, matches: matches);

  final CockpitTarget? target;
  final CockpitLocatorResolution? locatorResolution;
  final CockpitCommandError? error;
  final List<CockpitTarget> matches;

  bool get isSuccess => target != null && error == null;
}

final class CockpitTargetRegistry {
  static const int liveSnapshotTargetLimit = 120;

  CockpitTargetRegistry({this.routeName});

  final LinkedHashMap<String, CockpitTarget> _targets =
      LinkedHashMap<String, CockpitTarget>();

  String? routeName;
  CockpitDiscoveredTargetsProvider? discoveredTargetsProvider;

  List<CockpitTarget> get registeredTargets =>
      List.unmodifiable(_targets.values.toList(growable: false));

  List<CockpitTarget> get visibleTargets => List.unmodifiable(<CockpitTarget>[
        ..._explicitVisibleTargets(),
        ..._deduplicatedDiscoveredVisibleTargets(),
      ]);

  void register(CockpitTarget target) {
    _targets[target.registrationId] = target;
  }

  void unregister(String registrationId) {
    _targets.remove(registrationId);
  }

  CockpitTargetResolutionResult resolve(CockpitLocator locator) {
    for (final candidate in _flatten(locator)) {
      final matches = visibleTargets
          .where((target) => _matches(target, candidate))
          .toList(growable: false);

      if (matches.isEmpty) {
        continue;
      }

      if (candidate.index != null) {
        final indexedMatch = _selectIndexedMatch(matches, candidate);
        if (indexedMatch == null) {
          return CockpitTargetResolutionResult.failure(
            error: CockpitCommandError.targetNotFound(
              message:
                  'No matched target exists at the requested locator index.',
              details: <String, Object?>{
                'requestedLocator': candidate.toJson(),
                'matchedCount': matches.length,
                'requestedIndex': candidate.index,
                'candidates': _orderedMatches(
                  matches,
                  candidate,
                )
                    .map((target) => target.registrationId)
                    .toList(growable: false),
              },
            ),
            matches: matches,
          );
        }
        return CockpitTargetResolutionResult.success(
          target: indexedMatch,
          locatorResolution: CockpitLocatorResolution(
            matchedKind: candidate.kind,
            matchedValue: candidate.value,
            matchedSignals: _matchedSignals(candidate),
          ),
          matches: matches,
        );
      }

      if (matches.length > 1) {
        final preferredMatch = _selectPreferredMatch(matches, candidate);
        if (preferredMatch != null) {
          return CockpitTargetResolutionResult.success(
            target: preferredMatch,
            locatorResolution: CockpitLocatorResolution(
              matchedKind: candidate.kind,
              matchedValue: candidate.value,
              matchedSignals: _matchedSignals(candidate),
            ),
            matches: matches,
          );
        }
        return CockpitTargetResolutionResult.failure(
          error: CockpitCommandError.ambiguousTarget(
            message: 'Multiple targets matched ${candidate.kind.name}.',
            details: <String, Object?>{
              'matchedKind': candidate.kind.name,
              'matchedValue': candidate.value,
              'candidates': matches
                  .map((target) => target.registrationId)
                  .toList(growable: false),
            },
          ),
          matches: matches,
        );
      }

      return CockpitTargetResolutionResult.success(
        target: matches.single,
        locatorResolution: CockpitLocatorResolution(
          matchedKind: candidate.kind,
          matchedValue: candidate.value,
          matchedSignals: _matchedSignals(candidate),
        ),
        matches: matches,
      );
    }

    return CockpitTargetResolutionResult.failure(
      error: CockpitCommandError.targetNotFound(
        message: 'No visible target matched the requested locator chain.',
        details: <String, Object?>{'requestedLocator': locator.toJson()},
      ),
    );
  }

  CockpitSnapshot snapshot() {
    final targets = visibleTargets;
    final prioritizedTargets = _prioritizeForLiveSnapshot(targets);
    final truncatedTargets = prioritizedTargets
        .take(liveSnapshotTargetLimit)
        .map((target) => target.toSnapshotTarget())
        .toList(growable: false);

    return CockpitSnapshot(
      routeName: routeName,
      visibleTargets: truncatedTargets,
      truncated: prioritizedTargets.length > liveSnapshotTargetLimit,
      summary: CockpitSnapshotSummary(
        visibleTargetCount: targets.length,
        targetsWithCockpitIdCount:
            targets.where((target) => target.cockpitId != null).length,
        targetsWithTextCount: targets
            .where((target) => target.text != null && target.text!.isNotEmpty)
            .length,
        styleDetailsIncluded: false,
        diagnosticPropertiesIncluded: false,
        ancestorSummariesIncluded: false,
        rebuildSummaryIncluded: false,
        accessibilitySummaryIncluded: false,
      ),
    );
  }

  List<CockpitTarget> _prioritizeForLiveSnapshot(List<CockpitTarget> targets) {
    final prioritized = targets.toList(growable: false);
    prioritized.sort((left, right) {
      final commandCompare = right.supportedCommands.length.compareTo(
        left.supportedCommands.length,
      );
      if (commandCompare != 0) {
        return commandCompare;
      }

      final leftSignalScore = _signalScore(left);
      final rightSignalScore = _signalScore(right);
      final signalCompare = rightSignalScore.compareTo(leftSignalScore);
      if (signalCompare != 0) {
        return signalCompare;
      }

      return left.registrationId.compareTo(right.registrationId);
    });
    return prioritized;
  }

  int _signalScore(CockpitTarget target) {
    var score = 0;
    if (target.keyValue != null && target.keyValue!.isNotEmpty) {
      score += 4;
    }
    if (target.semanticId != null && target.semanticId!.isNotEmpty) {
      score += 3;
    }
    if (target.text != null && target.text!.isNotEmpty) {
      score += 2;
    }
    if (target.tooltip != null && target.tooltip!.isNotEmpty) {
      score += 1;
    }
    return score;
  }

  Iterable<CockpitLocator> _flatten(CockpitLocator locator) sync* {
    yield locator;
    for (final fallback in locator.fallbacks) {
      yield* _flatten(fallback);
    }
  }

  bool _matches(CockpitTarget target, CockpitLocator locator) {
    if (!locator.hasSignals) {
      return false;
    }
    for (final signal in locator.signals) {
      if (!_matchesSignal(target, signal.kind, signal.value)) {
        return false;
      }
    }
    final ancestor = locator.ancestor;
    if (ancestor != null &&
        !_matchesAncestorChain(target.locatorAncestors, ancestor)) {
      return false;
    }
    return true;
  }

  bool _matchesSignal(
    CockpitTarget target,
    CockpitLocatorKind kind,
    String value,
  ) {
    return switch (kind) {
      CockpitLocatorKind.cockpitId => target.cockpitId == value,
      CockpitLocatorKind.semanticId => target.semanticId == value,
      CockpitLocatorKind.key => target.keyValue == value,
      CockpitLocatorKind.text => _matchesTextLocator(target, value),
      CockpitLocatorKind.tooltip => target.tooltip == value,
      CockpitLocatorKind.type => _matchesTypeSignal(target.typeName, value),
      CockpitLocatorKind.route => target.routeName == value,
      CockpitLocatorKind.registrationId => target.registrationId == value,
      CockpitLocatorKind.path => _matchesPath(target.path, value),
    };
  }

  bool _matchesTextLocator(CockpitTarget target, String expected) {
    return <String?>[
      target.text,
      target.displayLabel,
      target.tooltip,
    ].any((candidate) => _matchesTextSignal(candidate, expected));
  }

  bool _matchesTextSignal(String? candidate, String expected) {
    final normalizedCandidate = _normalizeText(candidate);
    final normalizedExpected = _normalizeText(expected);
    if (normalizedCandidate == null || normalizedExpected == null) {
      return false;
    }
    if (normalizedCandidate == normalizedExpected) {
      return true;
    }
    return normalizedCandidate.contains(normalizedExpected);
  }

  bool _matchesTypeSignal(String? candidate, String expected) {
    final normalizedCandidate = _normalizeTypeName(candidate);
    final normalizedExpected = _normalizeTypeName(expected);
    if (normalizedCandidate == null || normalizedExpected == null) {
      return false;
    }
    return normalizedCandidate == normalizedExpected;
  }

  String? _normalizeText(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _normalizeTypeName(String? value) {
    final normalized = _normalizeText(value)?.toLowerCase();
    if (normalized == null) {
      return null;
    }
    final compact = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return compact.isEmpty ? null : compact;
  }

  List<CockpitTarget> _explicitVisibleTargets() {
    return _targets.values.where((target) {
      if (!target.isVisible) {
        return false;
      }
      return routeName == null || target.routeName == routeName;
    }).toList(growable: false);
  }

  List<CockpitTarget> _discoveredVisibleTargets() {
    final provider = discoveredTargetsProvider;
    if (provider == null) {
      return const <CockpitTarget>[];
    }

    return provider().where((target) {
      if (!target.isVisible) {
        return false;
      }
      return routeName == null || target.routeName == routeName;
    }).toList(growable: false);
  }

  List<CockpitTarget> _deduplicatedDiscoveredVisibleTargets() {
    final explicitTargets = _explicitVisibleTargets();
    if (explicitTargets.isEmpty) {
      return _discoveredVisibleTargets();
    }

    return _discoveredVisibleTargets().where((discovered) {
      return !explicitTargets.any(
        (explicit) => _targetsOverlap(explicit, discovered),
      );
    }).toList(growable: false);
  }

  bool _targetsOverlap(CockpitTarget explicit, CockpitTarget discovered) {
    final explicitNode = explicit.diagnosticNodeProvider?.call();
    final discoveredNode = discovered.diagnosticNodeProvider?.call();
    if (explicitNode != null &&
        discoveredNode != null &&
        identical(explicitNode, discoveredNode)) {
      return true;
    }
    if (_sameSignal(explicit.keyValue, discovered.keyValue)) {
      return true;
    }
    if (_sameSignal(explicit.cockpitId, discovered.cockpitId)) {
      return true;
    }
    if (_sameSignal(explicit.semanticId, discovered.semanticId)) {
      return true;
    }
    if (_sameSignal(explicit.tooltip, discovered.tooltip) &&
        explicit.typeName == discovered.typeName &&
        explicit.routeName == discovered.routeName) {
      return true;
    }
    if (_sameSignal(explicit.text, discovered.text) &&
        explicit.typeName == discovered.typeName &&
        explicit.routeName == discovered.routeName) {
      return true;
    }
    return false;
  }

  bool _sameSignal(String? left, String? right) {
    return left != null &&
        right != null &&
        left.isNotEmpty &&
        right.isNotEmpty &&
        left == right;
  }

  CockpitTarget? _selectPreferredMatch(
    List<CockpitTarget> matches,
    CockpitLocator locator,
  ) {
    if (matches.length < 2) {
      return matches.isEmpty ? null : matches.single;
    }

    final sorted = matches.toList(growable: false)
      ..sort((left, right) {
        final scoreCompare = _matchPriorityScore(
          right,
          locator,
        ).compareTo(_matchPriorityScore(left, locator));
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return left.registrationId.compareTo(right.registrationId);
      });

    final bestScore = _matchPriorityScore(sorted.first, locator);
    final hasTie = sorted.skip(1).any(
          (candidate) => _matchPriorityScore(candidate, locator) == bestScore,
        );
    if (hasTie || bestScore <= 0) {
      return null;
    }
    return sorted.first;
  }

  CockpitTarget? _selectIndexedMatch(
    List<CockpitTarget> matches,
    CockpitLocator locator,
  ) {
    final index = locator.index;
    if (index == null) {
      return null;
    }
    if (index < 0) {
      return null;
    }
    final ordered = _orderedMatches(matches, locator);
    if (index >= ordered.length) {
      return null;
    }
    return ordered[index];
  }

  List<CockpitTarget> _orderedMatches(
    List<CockpitTarget> matches,
    CockpitLocator locator,
  ) {
    final ordered = matches.toList(growable: false)
      ..sort((left, right) {
        final geometryCompare = _compareGeometry(left, right);
        if (geometryCompare != 0) {
          return geometryCompare;
        }

        final scoreCompare = _matchPriorityScore(
          right,
          locator,
        ).compareTo(_matchPriorityScore(left, locator));
        if (scoreCompare != 0) {
          return scoreCompare;
        }

        return left.registrationId.compareTo(right.registrationId);
      });
    return ordered;
  }

  int _compareGeometry(CockpitTarget left, CockpitTarget right) {
    final leftGeometry = left.geometryProvider?.call();
    final rightGeometry = right.geometryProvider?.call();
    if (leftGeometry == null || rightGeometry == null) {
      if (leftGeometry == null && rightGeometry == null) {
        return 0;
      }
      return leftGeometry == null ? 1 : -1;
    }

    final topCompare = leftGeometry.top.compareTo(rightGeometry.top);
    if (topCompare != 0) {
      return topCompare;
    }
    final leftCompare = leftGeometry.left.compareTo(rightGeometry.left);
    if (leftCompare != 0) {
      return leftCompare;
    }
    final areaCompare = _geometryArea(leftGeometry).compareTo(
      _geometryArea(rightGeometry),
    );
    if (areaCompare != 0) {
      return areaCompare;
    }
    return 0;
  }

  double _geometryArea(CockpitTargetGeometry geometry) {
    return geometry.width * geometry.height;
  }

  int _matchPriorityScore(CockpitTarget target, CockpitLocator locator) {
    var score = 0;
    final textSignal = locator.signalMap[CockpitLocatorKind.text.name];
    if (textSignal != null) {
      score += _textMatchPriorityScore(target, textSignal);
    }
    final pathSignal = locator.signalMap[CockpitLocatorKind.path.name];
    if (pathSignal != null) {
      score += _pathMatchPriorityScore(target.path, pathSignal);
    }
    final registrationIdSignal =
        locator.signalMap[CockpitLocatorKind.registrationId.name];
    if (registrationIdSignal != null &&
        target.registrationId == registrationIdSignal) {
      score += 40;
    }
    if (target.supportedCommands.isNotEmpty) {
      score += 8;
    }
    if (target.keyValue != null && target.keyValue!.isNotEmpty) {
      score += 4;
    }
    if (target.cockpitId != null && target.cockpitId!.isNotEmpty) {
      score += 3;
    }
    if (target.semanticId != null && target.semanticId!.isNotEmpty) {
      score += 2;
    }
    if (target.text != null && target.text!.isNotEmpty) {
      score += 1;
    }
    score += locator.signalMap.length * 2;
    return score;
  }

  bool _matchesAncestorChain(
    List<CockpitSnapshotAncestor> ancestors,
    CockpitLocator locator,
  ) {
    for (var index = 0; index < ancestors.length; index += 1) {
      if (!_matchesAncestor(ancestors[index], locator)) {
        continue;
      }
      final nested = locator.ancestor;
      if (nested == null) {
        return true;
      }
      if (_matchesAncestorChain(ancestors.sublist(index + 1), nested)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesAncestor(
    CockpitSnapshotAncestor ancestor,
    CockpitLocator locator,
  ) {
    for (final signal in locator.signals) {
      final matched = switch (signal.kind) {
        CockpitLocatorKind.cockpitId => ancestor.cockpitId == signal.value,
        CockpitLocatorKind.semanticId => ancestor.semanticId == signal.value ||
            ancestor.cockpitId == signal.value,
        CockpitLocatorKind.key => ancestor.keyValue == signal.value ||
            ancestor.cockpitId == signal.value,
        CockpitLocatorKind.text =>
          _matchesTextSignal(ancestor.textPreview, signal.value) ||
              _matchesTextSignal(ancestor.tooltip, signal.value),
        CockpitLocatorKind.tooltip =>
          _matchesTextSignal(ancestor.tooltip, signal.value),
        CockpitLocatorKind.type =>
          _matchesTypeSignal(ancestor.typeName, signal.value),
        CockpitLocatorKind.route => ancestor.routeName == signal.value,
        CockpitLocatorKind.path => _matchesPath(ancestor.path, signal.value),
        CockpitLocatorKind.registrationId => false,
      };
      if (!matched) {
        return false;
      }
    }
    return true;
  }

  bool _matchesPath(String? candidate, String expected) {
    final normalizedCandidate = _normalizePath(candidate);
    final normalizedExpected = _normalizePath(expected);
    if (normalizedCandidate == null || normalizedExpected == null) {
      return false;
    }
    return normalizedCandidate == normalizedExpected ||
        normalizedCandidate.endsWith(normalizedExpected) ||
        _isPathSubsequence(
          _pathSegments(normalizedCandidate),
          _pathSegments(normalizedExpected),
        );
  }

  String? _normalizePath(String? value) {
    final segments = _pathSegments(value);
    if (segments.isEmpty) {
      return null;
    }
    return '/${segments.join('/')}';
  }

  int _pathMatchPriorityScore(String? candidate, String expected) {
    final normalizedCandidate = _normalizePath(candidate);
    final normalizedExpected = _normalizePath(expected);
    if (normalizedCandidate == null || normalizedExpected == null) {
      return 0;
    }
    if (normalizedCandidate == normalizedExpected) {
      return 30;
    }
    if (normalizedCandidate.endsWith(normalizedExpected)) {
      return 20;
    }
    if (_isPathSubsequence(
      _pathSegments(normalizedCandidate),
      _pathSegments(normalizedExpected),
    )) {
      return 10;
    }
    return 0;
  }

  Map<String, String> _matchedSignals(CockpitLocator locator) {
    if (locator.signalMap.length <= 1 &&
        locator.ancestor == null &&
        locator.index == null) {
      return const <String, String>{};
    }
    return <String, String>{
      ...locator.signalMap,
      if (locator.index != null) 'index': '${locator.index}',
    };
  }

  List<String> _pathSegments(String? value) {
    final normalized = _normalizeText(value);
    if (normalized == null) {
      return const <String>[];
    }

    final canonical = normalized
        .replaceAll(RegExp(r'[>\[\]():\s]+'), '/')
        .replaceAll('.', '/');
    return canonical
        .split(RegExp(r'/+'))
        .map(_normalizePathSegment)
        .whereType<String>()
        .where((segment) => !_pathNoiseSegments.contains(segment))
        .toList(growable: false);
  }

  String? _normalizePathSegment(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return null;
    }
    if (RegExp(r'^\d+$').hasMatch(lower)) {
      return null;
    }
    final alphanumericOnly = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return alphanumericOnly.isEmpty ? null : alphanumericOnly;
  }

  bool _isPathSubsequence(
    List<String> candidateSegments,
    List<String> expectedSegments,
  ) {
    if (candidateSegments.isEmpty || expectedSegments.isEmpty) {
      return false;
    }
    var candidateIndex = 0;
    for (final expected in expectedSegments) {
      var found = false;
      while (candidateIndex < candidateSegments.length) {
        if (candidateSegments[candidateIndex] == expected) {
          found = true;
          candidateIndex += 1;
          break;
        }
        candidateIndex += 1;
      }
      if (!found) {
        return false;
      }
    }
    return true;
  }

  static const Set<String> _pathNoiseSegments = <String>{
    'actions',
    'appbaractions',
    'body',
    'child',
    'children',
    'content',
    'destination',
    'destinations',
    'footer',
    'header',
    'items',
    'leading',
    'slivers',
    'subtitle',
    'title',
    'trailing',
  };

  int _textMatchPriorityScore(CockpitTarget target, String expected) {
    final normalizedExpected = _normalizeText(expected);
    if (normalizedExpected == null) {
      return 0;
    }

    var bestScore = 0;
    for (final candidate in <(String?, int)>[
      (target.text, 30),
      (target.displayLabel, 20),
      (target.tooltip, 12),
    ]) {
      final normalizedCandidate = _normalizeText(candidate.$1);
      if (normalizedCandidate == null) {
        continue;
      }
      if (normalizedCandidate == normalizedExpected) {
        bestScore = bestScore < candidate.$2 ? candidate.$2 : bestScore;
        continue;
      }
      if (normalizedCandidate.contains(normalizedExpected)) {
        final partialScore = candidate.$2 ~/ 2;
        bestScore = bestScore < partialScore ? partialScore : bestScore;
      }
    }
    return bestScore;
  }
}
