import 'dart:async';

import 'package:cockpit_protocol/cockpit_protocol.dart';

import 'cockpit_suite_execution_plan.dart';
import 'cockpit_suite_scheduler.dart';

typedef CockpitSuiteRowAttemptFinished =
    Future<void> Function(CockpitSuitePlanNode caseNode);

final class CockpitSuiteRowAttemptExecutor
    implements CockpitSuiteAttemptExecutor {
  CockpitSuiteRowAttemptExecutor({
    required this.plan,
    required CockpitSuiteAttemptExecutor delegate,
    CockpitSuiteRowAttemptFinished? onAttemptFinished,
    DateTime Function()? utcNow,
  }) : _delegate = delegate,
       _onAttemptFinished = onAttemptFinished,
       _utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final CockpitSuiteExecutionPlan plan;
  final CockpitSuiteAttemptExecutor _delegate;
  final CockpitSuiteRowAttemptFinished? _onAttemptFinished;
  final DateTime Function() _utcNow;

  @override
  Future<CockpitTestAttemptReport> execute({
    required CockpitSuitePlanNode node,
    required String runId,
    required String attemptId,
    required int attemptNumber,
    required CockpitSuiteCancellation cancellation,
  }) async {
    if (node.kind != CockpitSuitePlanNodeKind.testCase) {
      return _delegate.execute(
        node: node,
        runId: runId,
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        cancellation: cancellation,
      );
    }
    return _executeRow(
      node: node,
      runId: runId,
      attemptId: attemptId,
      attemptNumber: attemptNumber,
      cancellation: cancellation,
    );
  }

  Future<CockpitTestAttemptReport> _executeRow({
    required CockpitSuitePlanNode node,
    required String runId,
    required String attemptId,
    required int attemptNumber,
    required CockpitSuiteCancellation cancellation,
  }) async {
    final startedAt = _utcNow();
    final lifecycle = plan.attemptNodesFor(node.nodeId).toList(growable: false);
    final isolation = lifecycle.singleWhere(
      (item) => item.kind == CockpitSuitePlanNodeKind.isolation,
    );
    final setups = _ordered(
      lifecycle.where(
        (item) => item.kind == CockpitSuitePlanNodeKind.fixtureSetup,
      ),
    );
    final teardowns = _ordered(
      lifecycle.where(
        (item) => item.kind == CockpitSuitePlanNodeKind.fixtureTeardown,
      ),
    );
    final attemptedSetups = <String>{};
    final cleanupReports = <CockpitTestAttemptReport>[];
    CockpitTestAttemptReport? primary;
    try {
      primary = await _executeSafely(
        node: isolation,
        runId: runId,
        attemptId: _internalAttemptId(attemptId, isolation),
        attemptNumber: attemptNumber,
        cancellation: cancellation,
      );
      if (primary.outcome == CockpitRunOutcome.passed) {
        primary = null;
        for (final setup in setups) {
          if (cancellation.isCancelled) {
            primary = _cancelled(node, attemptId, attemptNumber, startedAt);
            break;
          }
          attemptedSetups.add(setup.nodeId);
          final setupReport = await _executeSafely(
            node: setup,
            runId: runId,
            attemptId: _internalAttemptId(attemptId, setup),
            attemptNumber: attemptNumber,
            cancellation: cancellation,
          );
          if (setupReport.outcome != CockpitRunOutcome.passed) {
            primary = setupReport;
            break;
          }
        }
      }
      if (primary == null) {
        if (cancellation.isCancelled) {
          primary = _cancelled(node, attemptId, attemptNumber, startedAt);
        } else {
          primary = await _executeSafely(
            node: node,
            runId: runId,
            attemptId: attemptId,
            attemptNumber: attemptNumber,
            cancellation: cancellation,
          );
        }
      }
    } finally {
      for (final teardown in teardowns) {
        if (!attemptedSetups.contains(teardown.cleanupGuardNodeId)) continue;
        cleanupReports.add(
          await _executeSafely(
            node: teardown,
            runId: runId,
            attemptId: _internalAttemptId(attemptId, teardown),
            attemptNumber: attemptNumber,
            cancellation: const _NeverCancelled(),
          ),
        );
      }
      await _onAttemptFinished?.call(node);
    }
    return _compose(
      node: node,
      attemptId: attemptId,
      attemptNumber: attemptNumber,
      startedAt: startedAt,
      primary: primary,
      cleanupReports: cleanupReports,
    );
  }

  Future<CockpitTestAttemptReport> _executeSafely({
    required CockpitSuitePlanNode node,
    required String runId,
    required String attemptId,
    required int attemptNumber,
    required CockpitSuiteCancellation cancellation,
  }) async {
    final startedAt = _utcNow();
    try {
      return await _delegate.execute(
        node: node,
        runId: runId,
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        cancellation: cancellation,
      );
    } on Object {
      final finishedAt = _utcNow();
      return CockpitTestAttemptReport(
        attemptId: attemptId,
        number: attemptNumber,
        outcome: cancellation.isCancelled
            ? CockpitRunOutcome.cancelled
            : CockpitRunOutcome.internalError,
        startedAt: startedAt,
        finishedAt: finishedAt,
        durationMs: finishedAt.difference(startedAt).inMilliseconds,
        targetId: node.targetId ?? 'unassigned',
        failure: CockpitFailure(
          primary: CockpitApiError(
            code: cancellation.isCancelled
                ? CockpitErrorCode.cancelled
                : CockpitErrorCode.internalError,
            category: cancellation.isCancelled
                ? CockpitErrorCategory.cancelled
                : CockpitErrorCategory.internal,
            message: cancellation.isCancelled
                ? 'Suite case attempt was cancelled.'
                : 'Suite case attempt failed internally.',
            retryable: !cancellation.isCancelled,
            responsibleLayer: CockpitResponsibleLayer.worker,
          ),
        ),
      );
    }
  }

  CockpitTestAttemptReport _compose({
    required CockpitSuitePlanNode node,
    required String attemptId,
    required int attemptNumber,
    required DateTime startedAt,
    required CockpitTestAttemptReport primary,
    required List<CockpitTestAttemptReport> cleanupReports,
  }) {
    var outcome = primary.outcome;
    var failure = primary.failure;
    final artifacts = <CockpitArtifactReference>[...primary.artifacts];
    for (final cleanup in cleanupReports) {
      artifacts.addAll(cleanup.artifacts);
      if (cleanup.outcome == CockpitRunOutcome.passed) continue;
      final cleanupFailure = cleanup.failure ?? _cleanupFailure();
      if (failure == null) {
        outcome = cleanup.outcome;
        failure = cleanupFailure;
      } else {
        failure = CockpitFailure(
          primary: failure.primary,
          warnings: <CockpitApiWarning>[
            ...failure.warnings,
            CockpitApiWarning(
              stage: CockpitWarningStage.cleanup,
              error: cleanupFailure.primary,
            ),
            ...cleanupFailure.warnings,
          ],
        );
      }
    }
    final finishedAt = _utcNow();
    return CockpitTestAttemptReport(
      attemptId: attemptId,
      number: attemptNumber,
      outcome: outcome,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationMs: finishedAt.difference(startedAt).inMilliseconds,
      targetId: primary.targetId == 'unassigned'
          ? node.targetId ?? 'unassigned'
          : primary.targetId,
      failure: failure,
      artifacts: artifacts,
    );
  }

  CockpitTestAttemptReport _cancelled(
    CockpitSuitePlanNode node,
    String attemptId,
    int attemptNumber,
    DateTime startedAt,
  ) {
    final finishedAt = _utcNow();
    return CockpitTestAttemptReport(
      attemptId: attemptId,
      number: attemptNumber,
      outcome: CockpitRunOutcome.cancelled,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationMs: finishedAt.difference(startedAt).inMilliseconds,
      targetId: node.targetId ?? 'unassigned',
      failure: CockpitFailure(
        primary: CockpitApiError(
          code: CockpitErrorCode.cancelled,
          category: CockpitErrorCategory.cancelled,
          message: 'Suite case attempt was cancelled.',
          retryable: false,
          responsibleLayer: CockpitResponsibleLayer.worker,
        ),
      ),
    );
  }
}

List<CockpitSuitePlanNode> _ordered(Iterable<CockpitSuitePlanNode> source) {
  final pending = <String, CockpitSuitePlanNode>{
    for (final node in source) node.nodeId: node,
  };
  final relevantIds = pending.keys.toSet();
  final completed = <String>{};
  final result = <CockpitSuitePlanNode>[];
  while (pending.isNotEmpty) {
    final ready =
        pending.values
            .where(
              (node) => node.dependencies
                  .where(relevantIds.contains)
                  .every(completed.contains),
            )
            .toList()
          ..sort((left, right) => left.nodeId.compareTo(right.nodeId));
    if (ready.isEmpty) {
      throw const FormatException('Suite attempt lifecycle contains a cycle.');
    }
    for (final node in ready) {
      pending.remove(node.nodeId);
      completed.add(node.nodeId);
      result.add(node);
    }
  }
  return result;
}

String _internalAttemptId(String attemptId, CockpitSuitePlanNode node) =>
    '${attemptId}_${node.nodeId}';

CockpitFailure _cleanupFailure() => CockpitFailure(
  primary: CockpitApiError(
    code: 'suiteFixtureTeardownFailed',
    category: CockpitErrorCategory.environment,
    message: 'Suite fixture teardown did not complete successfully.',
    retryable: true,
    responsibleLayer: CockpitResponsibleLayer.worker,
  ),
);

final class _NeverCancelled implements CockpitSuiteCancellation {
  const _NeverCancelled();

  static final Future<void> _never = Completer<void>().future;

  @override
  bool get isCancelled => false;

  @override
  Future<void> get whenCancelled => _never;
}
