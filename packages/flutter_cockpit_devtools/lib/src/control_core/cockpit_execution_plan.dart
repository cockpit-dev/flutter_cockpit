import 'package:collection/collection.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_intent.dart';

final class CockpitExecutionPlan {
  CockpitExecutionPlan({
    required this.intent,
    required this.selectedPlane,
    required List<CockpitPlaneKind> candidatePlanes,
    required List<CockpitPlaneKind> fallbackChain,
    this.requiresEvidence = false,
    this.requiresObservation = false,
  })  : candidatePlanes = List.unmodifiable(candidatePlanes),
        fallbackChain = List.unmodifiable(fallbackChain);

  final CockpitIntent intent;
  final CockpitPlaneKind selectedPlane;
  final List<CockpitPlaneKind> candidatePlanes;
  final List<CockpitPlaneKind> fallbackChain;
  final bool requiresEvidence;
  final bool requiresObservation;

  static const ListEquality<CockpitPlaneKind> _planeListEquality =
      ListEquality<CockpitPlaneKind>();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitExecutionPlan &&
            other.intent == intent &&
            other.selectedPlane == selectedPlane &&
            _planeListEquality.equals(other.candidatePlanes, candidatePlanes) &&
            _planeListEquality.equals(other.fallbackChain, fallbackChain) &&
            other.requiresEvidence == requiresEvidence &&
            other.requiresObservation == requiresObservation;
  }

  @override
  int get hashCode => Object.hash(
        intent,
        selectedPlane,
        _planeListEquality.hash(candidatePlanes),
        _planeListEquality.hash(fallbackChain),
        requiresEvidence,
        requiresObservation,
      );
}
