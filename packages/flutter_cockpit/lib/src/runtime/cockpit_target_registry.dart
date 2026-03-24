// ignore_for_file: deprecated_member_use

import 'dart:collection';

import '../control/cockpit_locator.dart';
import '../control/cockpit_locator_resolution.dart';
import '../errors/cockpit_command_error.dart';
import 'cockpit_snapshot.dart';
import 'cockpit_target.dart';

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

      if (matches.length > 1) {
        final preferredMatch = _selectPreferredMatch(matches, candidate);
        if (preferredMatch != null) {
          return CockpitTargetResolutionResult.success(
            target: preferredMatch,
            locatorResolution: CockpitLocatorResolution(
              matchedKind: candidate.kind,
              matchedValue: candidate.value,
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
    return switch (locator.kind) {
      CockpitLocatorKind.cockpitId => target.cockpitId == locator.value,
      CockpitLocatorKind.semanticId => target.semanticId == locator.value,
      CockpitLocatorKind.key => target.keyValue == locator.value,
      CockpitLocatorKind.text => _matchesTextLocator(target, locator.value),
      CockpitLocatorKind.tooltip => target.tooltip == locator.value,
      CockpitLocatorKind.type => target.typeName == locator.value,
      CockpitLocatorKind.route => target.routeName == locator.value,
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

  String? _normalizeText(String? value) {
    if (value == null) {
      return null;
    }
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
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

  int _matchPriorityScore(CockpitTarget target, CockpitLocator locator) {
    var score = 0;
    if (locator.kind == CockpitLocatorKind.text) {
      score += _textMatchPriorityScore(target, locator.value);
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
    return score;
  }

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
