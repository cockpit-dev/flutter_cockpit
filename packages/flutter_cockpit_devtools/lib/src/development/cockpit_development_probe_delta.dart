final class CockpitDevelopmentProbeDelta {
  const CockpitDevelopmentProbeDelta({
    required this.fromProbeId,
    required this.toProbeId,
    required this.reloadGenerationChanged,
    required this.routeChanged,
    this.addedVisibleText = const <String>[],
    this.removedVisibleText = const <String>[],
    this.addedSemanticIds = const <String>[],
    this.removedSemanticIds = const <String>[],
    this.addedInteractiveLabels = const <String>[],
    this.removedInteractiveLabels = const <String>[],
    this.addedVisualSignals = const <String>[],
    this.removedVisualSignals = const <String>[],
    required this.focusChanged,
    required this.overlayChanged,
    required this.visualChanged,
    required this.screenshotChanged,
    this.newNetworkFailures = const <String>[],
    this.newRuntimeErrors = const <String>[],
    this.newRebuildHotspots = const <String>[],
    this.changeSummary,
  });

  final String fromProbeId;
  final String toProbeId;
  final bool reloadGenerationChanged;
  final bool routeChanged;
  final List<String> addedVisibleText;
  final List<String> removedVisibleText;
  final List<String> addedSemanticIds;
  final List<String> removedSemanticIds;
  final List<String> addedInteractiveLabels;
  final List<String> removedInteractiveLabels;
  final List<String> addedVisualSignals;
  final List<String> removedVisualSignals;
  final bool focusChanged;
  final bool overlayChanged;
  final bool visualChanged;
  final bool screenshotChanged;
  final List<String> newNetworkFailures;
  final List<String> newRuntimeErrors;
  final List<String> newRebuildHotspots;
  final String? changeSummary;

  Map<String, Object?> toJson() => <String, Object?>{
    'fromProbeId': fromProbeId,
    'toProbeId': toProbeId,
    'reloadGenerationChanged': reloadGenerationChanged,
    'routeChanged': routeChanged,
    'addedVisibleText': addedVisibleText,
    'removedVisibleText': removedVisibleText,
    'addedSemanticIds': addedSemanticIds,
    'removedSemanticIds': removedSemanticIds,
    'addedInteractiveLabels': addedInteractiveLabels,
    'removedInteractiveLabels': removedInteractiveLabels,
    'addedVisualSignals': addedVisualSignals,
    'removedVisualSignals': removedVisualSignals,
    'focusChanged': focusChanged,
    'overlayChanged': overlayChanged,
    'visualChanged': visualChanged,
    'screenshotChanged': screenshotChanged,
    'newNetworkFailures': newNetworkFailures,
    'newRuntimeErrors': newRuntimeErrors,
    'newRebuildHotspots': newRebuildHotspots,
    if (changeSummary != null) 'changeSummary': changeSummary,
  };

  factory CockpitDevelopmentProbeDelta.fromJson(Map<String, Object?> json) {
    return CockpitDevelopmentProbeDelta(
      fromProbeId: json['fromProbeId']! as String,
      toProbeId: json['toProbeId']! as String,
      reloadGenerationChanged:
          json['reloadGenerationChanged'] as bool? ?? false,
      routeChanged: json['routeChanged'] as bool? ?? false,
      addedVisibleText: _readStringList(json['addedVisibleText']),
      removedVisibleText: _readStringList(json['removedVisibleText']),
      addedSemanticIds: _readStringList(json['addedSemanticIds']),
      removedSemanticIds: _readStringList(json['removedSemanticIds']),
      addedInteractiveLabels: _readStringList(json['addedInteractiveLabels']),
      removedInteractiveLabels: _readStringList(
        json['removedInteractiveLabels'],
      ),
      addedVisualSignals: _readStringList(json['addedVisualSignals']),
      removedVisualSignals: _readStringList(json['removedVisualSignals']),
      focusChanged: json['focusChanged'] as bool? ?? false,
      overlayChanged: json['overlayChanged'] as bool? ?? false,
      visualChanged: json['visualChanged'] as bool? ?? false,
      screenshotChanged: json['screenshotChanged'] as bool? ?? false,
      newNetworkFailures: _readStringList(json['newNetworkFailures']),
      newRuntimeErrors: _readStringList(json['newRuntimeErrors']),
      newRebuildHotspots: _readStringList(json['newRebuildHotspots']),
      changeSummary: json['changeSummary'] as String?,
    );
  }

  static List<String> _readStringList(Object? json) {
    return (json as List<Object?>? ?? const <Object?>[])
        .map((value) => value! as String)
        .toList(growable: false);
  }
}
