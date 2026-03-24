import 'package:collection/collection.dart';

import '../runtime/cockpit_snapshot.dart';
import '../runtime/cockpit_snapshot_options.dart';
import 'cockpit_artifact_ref.dart';

enum CockpitObservationPhase {
  baseline,
  beforeAction,
  afterAction,
  failure;

  static CockpitObservationPhase fromJson(Object? json) {
    return values.byName(json! as String);
  }
}

final class CockpitObservation {
  CockpitObservation({
    this.routeName,
    List<String> interactiveElements = const [],
    this.phase,
    this.diagnosticLevel,
    this.truncated = false,
    this.diagnosticsArtifactRef,
    this.summary,
  }) : interactiveElements = List.unmodifiable(interactiveElements);

  final String? routeName;
  final List<String> interactiveElements;
  final CockpitObservationPhase? phase;
  final CockpitSnapshotProfile? diagnosticLevel;
  final bool truncated;
  final CockpitArtifactRef? diagnosticsArtifactRef;
  final CockpitSnapshotSummary? summary;

  static const ListEquality<String> _listEquality = ListEquality<String>();

  Map<String, Object?> toJson() => {
        'routeName': routeName,
        'interactiveElements': interactiveElements,
        'phase': phase?.name,
        'diagnosticLevel': diagnosticLevel?.jsonValue,
        'truncated': truncated,
        'diagnosticsArtifactRef': diagnosticsArtifactRef?.toJson(),
        'summary': summary?.toJson(),
      };

  factory CockpitObservation.fromJson(Map<String, Object?> json) {
    final interactiveElements =
        (json['interactiveElements'] as List<Object?>? ?? const <Object?>[])
            .cast<String>();
    final diagnosticsArtifactJson =
        json['diagnosticsArtifactRef'] as Map<Object?, Object?>?;
    final summaryJson = json['summary'] as Map<Object?, Object?>?;

    return CockpitObservation(
      routeName: json['routeName'] as String?,
      interactiveElements: interactiveElements,
      phase: json['phase'] == null
          ? null
          : CockpitObservationPhase.fromJson(json['phase']),
      diagnosticLevel: json['diagnosticLevel'] == null
          ? null
          : CockpitSnapshotProfile.fromJson(json['diagnosticLevel']),
      truncated: json['truncated'] as bool? ?? false,
      diagnosticsArtifactRef: diagnosticsArtifactJson == null
          ? null
          : CockpitArtifactRef.fromJson(
              Map<String, Object?>.from(diagnosticsArtifactJson),
            ),
      summary: summaryJson == null
          ? null
          : CockpitSnapshotSummary.fromJson(
              Map<String, Object?>.from(summaryJson),
            ),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitObservation &&
            other.routeName == routeName &&
            other.phase == phase &&
            other.diagnosticLevel == diagnosticLevel &&
            other.truncated == truncated &&
            other.diagnosticsArtifactRef == diagnosticsArtifactRef &&
            other.summary == summary &&
            _listEquality.equals(
              other.interactiveElements,
              interactiveElements,
            );
  }

  @override
  int get hashCode => Object.hash(
        routeName,
        phase,
        diagnosticLevel,
        truncated,
        diagnosticsArtifactRef,
        summary,
        _listEquality.hash(interactiveElements),
      );
}
