import 'dart:convert';
import 'dart:io';

import '../development/cockpit_development_probe.dart';
import '../development/cockpit_development_probe_delta.dart';
import 'cockpit_application_service_exception.dart';

final class CockpitCompareDevelopmentProbeRequest {
  const CockpitCompareDevelopmentProbeRequest({
    this.fromProbe,
    this.fromProbePath,
    this.toProbe,
    this.toProbePath,
  });

  final CockpitDevelopmentProbe? fromProbe;
  final String? fromProbePath;
  final CockpitDevelopmentProbe? toProbe;
  final String? toProbePath;
}

final class CockpitCompareDevelopmentProbeResult {
  const CockpitCompareDevelopmentProbeResult({
    required this.fromProbe,
    required this.toProbe,
    required this.delta,
  });

  final CockpitDevelopmentProbe fromProbe;
  final CockpitDevelopmentProbe toProbe;
  final CockpitDevelopmentProbeDelta delta;

  Map<String, Object?> toJson() => <String, Object?>{
        'fromProbe': fromProbe.toJson(),
        'toProbe': toProbe.toJson(),
        'delta': delta.toJson(),
      };
}

final class CockpitCompareDevelopmentProbeService {
  const CockpitCompareDevelopmentProbeService();

  Future<CockpitCompareDevelopmentProbeResult> compare(
    CockpitCompareDevelopmentProbeRequest request,
  ) async {
    final fromProbe = await _resolveProbe(
      probe: request.fromProbe,
      probePath: request.fromProbePath,
      side: 'from',
    );
    final toProbe = await _resolveProbe(
      probe: request.toProbe,
      probePath: request.toProbePath,
      side: 'to',
    );
    final delta = CockpitDevelopmentProbeDelta(
      fromProbeId: fromProbe.probeId,
      toProbeId: toProbe.probeId,
      reloadGenerationChanged:
          fromProbe.reloadGeneration != toProbe.reloadGeneration,
      routeChanged: fromProbe.routeName != toProbe.routeName,
      addedVisibleText: _addedItems(
        _stringList(fromProbe.ui['visibleTextPreviews']),
        _stringList(toProbe.ui['visibleTextPreviews']),
      ),
      removedVisibleText: _removedItems(
        _stringList(fromProbe.ui['visibleTextPreviews']),
        _stringList(toProbe.ui['visibleTextPreviews']),
      ),
      addedSemanticIds: _addedItems(
        _stringList(fromProbe.ui['visibleSemanticIds']),
        _stringList(toProbe.ui['visibleSemanticIds']),
      ),
      removedSemanticIds: _removedItems(
        _stringList(fromProbe.ui['visibleSemanticIds']),
        _stringList(toProbe.ui['visibleSemanticIds']),
      ),
      addedInteractiveLabels: _addedItems(
        _stringList(fromProbe.ui['interactiveLabels']),
        _stringList(toProbe.ui['interactiveLabels']),
      ),
      removedInteractiveLabels: _removedItems(
        _stringList(fromProbe.ui['interactiveLabels']),
        _stringList(toProbe.ui['interactiveLabels']),
      ),
      addedVisualSignals: _addedItems(
        _stringList(fromProbe.ui['visualSignals']),
        _stringList(toProbe.ui['visualSignals']),
      ),
      removedVisualSignals: _removedItems(
        _stringList(fromProbe.ui['visualSignals']),
        _stringList(toProbe.ui['visualSignals']),
      ),
      focusChanged: _normalizedString(fromProbe.ui['focusedTargetLabel']) !=
          _normalizedString(toProbe.ui['focusedTargetLabel']),
      overlayChanged: !_listEquals(
        _stringList(fromProbe.ui['overlayLabels']),
        _stringList(toProbe.ui['overlayLabels']),
      ),
      visualChanged: !_listEquals(
        _stringList(fromProbe.ui['visualSignals']),
        _stringList(toProbe.ui['visualSignals']),
      ),
      screenshotChanged:
          _normalizedString(fromProbe.artifacts['screenshotDigest']) !=
              _normalizedString(toProbe.artifacts['screenshotDigest']),
      newNetworkFailures: _newItems(
        _stringList(fromProbe.network['failureSignals']),
        _stringList(toProbe.network['failureSignals']),
      ),
      newRuntimeErrors: _newItems(
        _stringList(fromProbe.runtime['errorSignals']),
        _stringList(toProbe.runtime['errorSignals']),
      ),
      newRebuildHotspots: _newItems(
        _stringList(fromProbe.rebuild['hotspots']),
        _stringList(toProbe.rebuild['hotspots']),
      ),
      changeSummary: _buildSummary(fromProbe, toProbe),
    );
    return CockpitCompareDevelopmentProbeResult(
      fromProbe: fromProbe,
      toProbe: toProbe,
      delta: delta,
    );
  }

  Future<CockpitDevelopmentProbe> _resolveProbe({
    required CockpitDevelopmentProbe? probe,
    required String? probePath,
    required String side,
  }) async {
    if (probe != null) {
      return probe;
    }
    if (probePath == null || probePath.isEmpty) {
      throw CockpitApplicationServiceException(
        code: 'missing_${side}_probe',
        message: 'Development probe is required for $side comparison side.',
      );
    }
    final file = File(probePath);
    if (!file.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'missing_${side}_probe_file',
        message: 'Development probe file does not exist: $probePath',
      );
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalid_${side}_probe_json',
        message: 'Development probe file must decode to a JSON object.',
      );
    }
    final normalized = Map<String, Object?>.from(decoded);
    final probeJson = normalized['probe'];
    if (probeJson case final Map<Object?, Object?> wrappedProbe) {
      return CockpitDevelopmentProbe.fromJson(
        Map<String, Object?>.from(wrappedProbe),
      );
    }
    return CockpitDevelopmentProbe.fromJson(normalized);
  }

  String _buildSummary(
    CockpitDevelopmentProbe fromProbe,
    CockpitDevelopmentProbe toProbe,
  ) {
    final changes = <String>[];
    if (fromProbe.routeName != toProbe.routeName) {
      changes.add('route changed');
    }
    if (!_listEquals(
      _stringList(fromProbe.ui['visibleTextPreviews']),
      _stringList(toProbe.ui['visibleTextPreviews']),
    )) {
      changes.add('visible text changed');
    }
    if (!_listEquals(
      _stringList(fromProbe.ui['visibleSemanticIds']),
      _stringList(toProbe.ui['visibleSemanticIds']),
    )) {
      changes.add('semantic ids changed');
    }
    if (!_listEquals(
      _stringList(fromProbe.ui['interactiveLabels']),
      _stringList(toProbe.ui['interactiveLabels']),
    )) {
      changes.add('interactive labels changed');
    }
    if (!_listEquals(
      _stringList(fromProbe.ui['visualSignals']),
      _stringList(toProbe.ui['visualSignals']),
    )) {
      changes.add('visual summary changed');
    }
    if (_normalizedString(fromProbe.artifacts['screenshotDigest']) !=
        _normalizedString(toProbe.artifacts['screenshotDigest'])) {
      changes.add('screenshot changed');
    }
    if (_normalizedString(fromProbe.ui['focusedTargetLabel']) !=
        _normalizedString(toProbe.ui['focusedTargetLabel'])) {
      changes.add('focus changed');
    }
    if (!_listEquals(
      _stringList(fromProbe.ui['overlayLabels']),
      _stringList(toProbe.ui['overlayLabels']),
    )) {
      changes.add('overlay changed');
    }
    if (_newItems(
      _stringList(fromProbe.network['failureSignals']),
      _stringList(toProbe.network['failureSignals']),
    ).isNotEmpty) {
      changes.add('network failures changed');
    }
    if (_newItems(
      _stringList(fromProbe.runtime['errorSignals']),
      _stringList(toProbe.runtime['errorSignals']),
    ).isNotEmpty) {
      changes.add('runtime errors changed');
    }
    if (_newItems(
      _stringList(fromProbe.rebuild['hotspots']),
      _stringList(toProbe.rebuild['hotspots']),
    ).isNotEmpty) {
      changes.add('rebuild hotspots changed');
    }
    if (changes.isEmpty) {
      return 'No observable development probe changes detected.';
    }
    return changes.join(', ');
  }

  static List<String> _addedItems(List<String> from, List<String> to) {
    final fromSet = from.toSet();
    return to.where((item) => !fromSet.contains(item)).toList(growable: false);
  }

  static List<String> _removedItems(List<String> from, List<String> to) {
    final toSet = to.toSet();
    return from.where((item) => !toSet.contains(item)).toList(growable: false);
  }

  static List<String> _newItems(List<String> from, List<String> to) {
    final fromSet = from.toSet();
    return to.where((item) => !fromSet.contains(item)).toList(growable: false);
  }

  static List<String> _stringList(Object? value) {
    return (value as List<Object?>? ?? const <Object?>[])
        .map((entry) => entry.toString())
        .toList(growable: false);
  }

  static String? _normalizedString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static bool _listEquals(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
