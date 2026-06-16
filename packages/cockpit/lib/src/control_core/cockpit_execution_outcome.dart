import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_fallback_step.dart';

final class CockpitExecutionOutcome {
  CockpitExecutionOutcome({
    required this.selectedPlane,
    this.fallbackTrail = const <CockpitFallbackStep>[],
    this.recommendedNextStep,
  });

  final CockpitPlaneKind selectedPlane;
  final List<CockpitFallbackStep> fallbackTrail;
  final String? recommendedNextStep;
}
