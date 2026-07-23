import 'package:cockpit_protocol/cockpit_protocol.dart';

import 'cockpit_suite_execution_plan.dart';
import 'cockpit_suite_scheduler.dart';

final class CockpitSuiteReportAssembler {
  const CockpitSuiteReportAssembler();

  CockpitTestSuiteReport assemble({
    required String projectId,
    required String workspaceId,
    required String runId,
    required CockpitSuiteExecutionPlan plan,
    required CockpitSuiteScheduleResult schedule,
    required DateTime startedAt,
    required DateTime finishedAt,
    Map<String, Object?> environment = const <String, Object?>{},
    Iterable<CockpitArtifactReference> artifacts =
        const <CockpitArtifactReference>[],
  }) {
    final cases = <CockpitTestCaseReport>[];
    for (final node in plan.caseNodes) {
      final execution = schedule.executionFor(node.nodeId);
      final targetId = execution.attempts.isEmpty
          ? node.targetId ?? 'unassigned'
          : execution.attempts.last.targetId;
      cases.add(
        CockpitTestCaseReport(
          entryId: node.entryId,
          caseId: node.compiledCase.testCase.id,
          sourceSha256: node.compiledCase.sourceSha256,
          outcome: execution.outcome,
          stability: execution.stability,
          targetId: targetId,
          matrix: node.matrix,
          attempts: execution.attempts,
        ),
      );
    }
    final outcome = _outcome(cases.map((item) => item.outcome));
    final stability =
        cases.any((item) => item.stability == CockpitRunStability.flaky)
        ? CockpitRunStability.flaky
        : CockpitRunStability.stable;
    return CockpitTestSuiteReport(
      projectId: projectId,
      workspaceId: workspaceId,
      runId: runId,
      suiteId: plan.suite.id,
      sourceSha256: plan.sourceSha256,
      outcome: outcome,
      stability: stability,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationMs: finishedAt.difference(startedAt).inMilliseconds,
      execution: plan.suite.execution,
      reportPolicy: plan.suite.report,
      environment: environment,
      matrixAxes: plan.suite.matrix.axes,
      cases: cases,
      artifacts: artifacts,
    );
  }
}

CockpitRunOutcome _outcome(Iterable<CockpitRunOutcome> outcomes) {
  final values = outcomes.toSet();
  for (final candidate in const <CockpitRunOutcome>[
    CockpitRunOutcome.internalError,
    CockpitRunOutcome.interrupted,
    CockpitRunOutcome.cancelled,
    CockpitRunOutcome.failed,
    CockpitRunOutcome.blocked,
  ]) {
    if (values.contains(candidate)) return candidate;
  }
  return CockpitRunOutcome.passed;
}
