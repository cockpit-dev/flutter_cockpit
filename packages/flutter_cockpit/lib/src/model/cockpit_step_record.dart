import 'package:collection/collection.dart';

import '../capture/cockpit_capture_kind.dart';
import '../capture/cockpit_capture_profile.dart';
import '../control/cockpit_command_status.dart';
import '../control/cockpit_command_type.dart';
import '../control/cockpit_locator.dart';
import '../control/cockpit_locator_resolution.dart';
import '../runtime/cockpit_snapshot.dart';
import 'cockpit_artifact_ref.dart';
import 'cockpit_observation.dart';

final class CockpitStepRecord {
  CockpitStepRecord({
    required this.index,
    required this.actionType,
    required Map<String, Object?> actionArgs,
    required this.observedAt,
    this.observation,
    this.snapshot,
    List<CockpitArtifactRef> artifactRefs = const [],
    this.commandType,
    this.locator,
    this.locatorResolution,
    this.durationMs,
    this.status,
    this.requestedCaptureProfile,
    this.resolvedCaptureKind,
    this.usedCaptureFallback = false,
    this.degradationReason,
    List<CockpitArtifactRef> captureRefs = const [],
  })  : actionArgs = Map.unmodifiable(actionArgs),
        artifactRefs = List.unmodifiable(artifactRefs),
        captureRefs = List.unmodifiable(captureRefs);

  final int index;
  final String actionType;
  final Map<String, Object?> actionArgs;
  final DateTime observedAt;
  final CockpitObservation? observation;
  final CockpitSnapshot? snapshot;
  final List<CockpitArtifactRef> artifactRefs;
  final CockpitCommandType? commandType;
  final CockpitLocator? locator;
  final CockpitLocatorResolution? locatorResolution;
  final int? durationMs;
  final CockpitCommandStatus? status;
  final CockpitCaptureProfile? requestedCaptureProfile;
  final CockpitCaptureKind? resolvedCaptureKind;
  final bool usedCaptureFallback;
  final String? degradationReason;
  final List<CockpitArtifactRef> captureRefs;

  static const MapEquality<String, Object?> _mapEquality =
      MapEquality<String, Object?>();
  static const ListEquality<CockpitArtifactRef> _artifactListEquality =
      ListEquality<CockpitArtifactRef>();

  Map<String, Object?> toJson() => {
        'index': index,
        'actionType': actionType,
        'actionArgs': actionArgs,
        'observedAt': observedAt.toUtc().toIso8601String(),
        'observation': observation?.toJson(),
        'snapshot': snapshot?.toJson(),
        'artifactRefs':
            artifactRefs.map((artifact) => artifact.toJson()).toList(),
        'commandType': commandType?.name,
        'locator': locator?.toJson(),
        'locatorResolution': locatorResolution?.toJson(),
        'durationMs': durationMs,
        'status': status?.name,
        'requestedCaptureProfile': requestedCaptureProfile?.name,
        'resolvedCaptureKind': resolvedCaptureKind?.name,
        'usedCaptureFallback': usedCaptureFallback,
        'degradationReason': degradationReason,
        'captureRefs':
            captureRefs.map((artifact) => artifact.toJson()).toList(),
      };

  factory CockpitStepRecord.fromJson(Map<String, Object?> json) {
    final actionArgs = Map<String, Object?>.from(
      (json['actionArgs'] as Map<Object?, Object?>?) ??
          const <Object?, Object?>{},
    );
    final artifactRefs =
        (json['artifactRefs'] as List<Object?>? ?? const <Object?>[])
            .cast<Map<Object?, Object?>>()
            .map(
              (item) =>
                  CockpitArtifactRef.fromJson(Map<String, Object?>.from(item)),
            )
            .toList();
    final observationJson = json['observation'] as Map<Object?, Object?>?;
    final snapshotJson = json['snapshot'] as Map<Object?, Object?>?;
    final locatorJson = json['locator'] as Map<Object?, Object?>?;
    final locatorResolutionJson =
        json['locatorResolution'] as Map<Object?, Object?>?;
    final captureRefs =
        (json['captureRefs'] as List<Object?>? ?? const <Object?>[])
            .cast<Map<Object?, Object?>>()
            .map(
              (item) =>
                  CockpitArtifactRef.fromJson(Map<String, Object?>.from(item)),
            )
            .toList();

    return CockpitStepRecord(
      index: json['index']! as int,
      actionType: json['actionType']! as String,
      actionArgs: actionArgs,
      observedAt: DateTime.parse(json['observedAt']! as String).toUtc(),
      observation: observationJson == null
          ? null
          : CockpitObservation.fromJson(
              Map<String, Object?>.from(observationJson),
            ),
      snapshot: snapshotJson == null
          ? null
          : CockpitSnapshot.fromJson(Map<String, Object?>.from(snapshotJson)),
      artifactRefs: artifactRefs,
      commandType: json['commandType'] == null
          ? null
          : CockpitCommandType.fromJson(json['commandType']),
      locator: locatorJson == null
          ? null
          : CockpitLocator.fromJson(Map<String, Object?>.from(locatorJson)),
      locatorResolution: locatorResolutionJson == null
          ? null
          : CockpitLocatorResolution.fromJson(
              Map<String, Object?>.from(locatorResolutionJson),
            ),
      durationMs: json['durationMs'] as int?,
      status: json['status'] == null
          ? null
          : CockpitCommandStatus.fromJson(json['status']),
      requestedCaptureProfile: json['requestedCaptureProfile'] == null
          ? null
          : CockpitCaptureProfile.fromJson(json['requestedCaptureProfile']),
      resolvedCaptureKind: json['resolvedCaptureKind'] == null
          ? null
          : CockpitCaptureKind.fromJson(json['resolvedCaptureKind']),
      usedCaptureFallback: json['usedCaptureFallback'] as bool? ?? false,
      degradationReason: json['degradationReason'] as String?,
      captureRefs: captureRefs,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitStepRecord &&
            other.index == index &&
            other.actionType == actionType &&
            _mapEquality.equals(other.actionArgs, actionArgs) &&
            other.observedAt == observedAt &&
            other.observation == observation &&
            other.snapshot == snapshot &&
            other.commandType == commandType &&
            other.locator == locator &&
            other.locatorResolution == locatorResolution &&
            other.durationMs == durationMs &&
            other.status == status &&
            other.requestedCaptureProfile == requestedCaptureProfile &&
            other.resolvedCaptureKind == resolvedCaptureKind &&
            other.usedCaptureFallback == usedCaptureFallback &&
            other.degradationReason == degradationReason &&
            _artifactListEquality.equals(other.artifactRefs, artifactRefs) &&
            _artifactListEquality.equals(other.captureRefs, captureRefs);
  }

  @override
  int get hashCode => Object.hash(
        index,
        actionType,
        _mapEquality.hash(actionArgs),
        observedAt,
        observation,
        snapshot,
        commandType,
        locator,
        locatorResolution,
        durationMs,
        status,
        requestedCaptureProfile,
        resolvedCaptureKind,
        usedCaptureFallback,
        degradationReason,
        _artifactListEquality.hash(artifactRefs),
        _artifactListEquality.hash(captureRefs),
      );
}
