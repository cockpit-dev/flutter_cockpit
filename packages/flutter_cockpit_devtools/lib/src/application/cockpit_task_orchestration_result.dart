import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_run_task_service.dart';
import 'cockpit_task_gate.dart';
import 'cockpit_task_stage.dart';

final class CockpitTaskOrchestrationResult {
  CockpitTaskOrchestrationResult({
    required this.classification,
    required this.recommendedNextStep,
    required Iterable<CockpitTaskStage> completedStages,
    required Map<CockpitTaskGate, bool> gates,
    this.sessionHandle,
    this.preflightStatus,
    this.bundleSummary,
    this.blockedReason,
  })  : completedStages = Set<CockpitTaskStage>.unmodifiable(completedStages),
        gates = Map<CockpitTaskGate, bool>.unmodifiable(gates);

  final CockpitRunTaskClassification classification;
  final String recommendedNextStep;
  final Set<CockpitTaskStage> completedStages;
  final Map<CockpitTaskGate, bool> gates;
  final CockpitRemoteSessionHandle? sessionHandle;
  final CockpitRemoteSessionStatus? preflightStatus;
  final CockpitReadTaskBundleSummaryResult? bundleSummary;
  final String? blockedReason;

  bool isGateSatisfied(CockpitTaskGate gate) => gates[gate] ?? false;
}
