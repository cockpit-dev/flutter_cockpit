import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../runner/cockpit_case_execution_control.dart';
import '../runner/cockpit_case_runner.dart';
import '../suite/cockpit_suite_compiler.dart';
import '../suite/cockpit_suite_execution_plan.dart';
import '../suite/cockpit_suite_report_assembler.dart';
import '../suite/cockpit_suite_report_writer.dart';
import '../suite/cockpit_suite_scheduler.dart';
import '../test/cockpit_test_document_compiler.dart';
import '../test/cockpit_test_safety_policy.dart';
import '../test/cockpit_test_secret_resolver.dart';
import '../test/cockpit_test_variable_binder.dart';
import 'cockpit_case_run_adapter.dart';
import 'cockpit_worker_artifact_publisher.dart';
import 'cockpit_worker_document_index.dart';
import 'cockpit_worker_resource_grant.dart';
import 'cockpit_worker_resource_scope.dart';
import 'cockpit_worker_run_event_store.dart';
import 'cockpit_worker_suite_run_store.dart';
import 'cockpit_worker_logger.dart';
import 'cockpit_workspace_operation_registry.dart';

final class CockpitSuiteRunAdapterFactory {
  CockpitSuiteRunAdapterFactory({
    required this.workspaceId,
    required this.projectId,
    required this.engineVersion,
    required this.runStateRoot,
    required CockpitWorkerDocumentIndex documents,
    required CockpitWorkerSessionProvider sessions,
    required CockpitWorkerResourceAuthorityClient resourceAuthority,
    required CockpitTestSecretResolver secretResolver,
    required CockpitTestSafetyPolicy safetyPolicy,
    required CockpitWorkerLogRedactor redactor,
    required CockpitWorkerRunEventStore eventStore,
    required CockpitWorkerSuiteRunStore runStore,
    CockpitWorkerArtifactPublisher? artifactPublisher,
    DateTime Function()? utcNow,
  }) : _documents = documents,
       _sessions = sessions,
       _resourceAuthority = resourceAuthority,
       _secretResolver = secretResolver,
       _safetyPolicy = safetyPolicy,
       _redactor = redactor,
       _eventStore = eventStore,
       _runStore = runStore,
       _artifactPublisher = artifactPublisher,
       _utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final String workspaceId;
  final String projectId;
  final String engineVersion;
  final String runStateRoot;
  final CockpitWorkerDocumentIndex _documents;
  final CockpitWorkerSessionProvider _sessions;
  final CockpitWorkerResourceAuthorityClient _resourceAuthority;
  final CockpitTestSecretResolver _secretResolver;
  final CockpitTestSafetyPolicy _safetyPolicy;
  final CockpitWorkerLogRedactor _redactor;
  final CockpitWorkerRunEventStore _eventStore;
  final CockpitWorkerSuiteRunStore _runStore;
  final CockpitWorkerArtifactPublisher? _artifactPublisher;
  final DateTime Function() _utcNow;

  CockpitWorkspaceOperationAdapter
  runAdapter() => CockpitWorkspaceOperationAdapter(
    kind: 'suite.run',
    mutationClass: CockpitMutationClass.mutating,
    resourceKinds: const <String>['workspace.runs'],
    prepare: (context, input) async {
      final submission = CockpitRunSubmission.fromJson(input);
      final source = submission.source;
      if (source is! CockpitSuiteSubmissionSource) {
        throw const FormatException('Suite run requires a suite source.');
      }
      if (submission.workspaceId != workspaceId ||
          submission.idempotencyKey.value != context.idempotencyKey) {
        throw const FormatException('Suite run identity mismatch.');
      }
      final missing = submission.requiredFeatures
          .where((feature) => !context.requiredFeatures.contains(feature))
          .toList(growable: false);
      if (missing.isNotEmpty) {
        throw FormatException(
          'Suite run required features are unavailable: ${missing.join(', ')}.',
        );
      }
      final compiled = await _compiled(source);
      final plan = await const CockpitSuiteCompiler().compile(
        compiledSuite: compiled,
        resolver: _documents,
      );
      final runId = 'run_${context.requestId}';
      final reservation = await _runStore.reserve(
        runId: runId,
        idempotencyKey: context.idempotencyKey,
        requestFingerprint: _fingerprint(submission, plan),
        suiteId: compiled.suite.id,
        sourceSha256: compiled.sourceSha256,
        startedAt: _utcNow(),
      );
      if (reservation.completed) {
        return CockpitPreparedWorkspaceOperation(
          resources: const <CockpitWorkerResourceRequest>[],
          isIdempotentReplay: true,
          execute: (_) async => reservation.completedOutput!,
        );
      }
      return CockpitPreparedWorkspaceOperation(
        resources: <CockpitWorkerResourceRequest>[
          CockpitWorkerResourceRequest(
            resourceKind: CockpitLeaseResourceKind.run,
            resourceId: runId,
            ttl: _resourceTtl(context.deadline),
          ),
        ],
        execute: (_) => _execute(
          context: context,
          submission: submission,
          plan: plan,
          reservation: reservation,
        ),
      );
    },
  );

  Future<CockpitCompiledTestSuite> _compiled(
    CockpitSuiteSubmissionSource source,
  ) => switch (source) {
    CockpitInlineSuiteSource() => Future<CockpitCompiledTestSuite>.value(
      CockpitCompiledTestSuite(
        suite: source.suite,
        sourceSha256: source.sourceSha256,
        sourceMap: const <String, CockpitTestSourceLocation>{},
      ),
    ),
    CockpitIndexedSuiteSource() => _documents.resolveSuite(source.reference),
  };

  Future<Map<String, Object?>> _execute({
    required CockpitWorkspaceOperationContext context,
    required CockpitRunSubmission submission,
    required CockpitSuiteExecutionPlan plan,
    required CockpitWorkerSuiteReservation reservation,
  }) async {
    final runId = reservation.runId;
    await _initializeEvents(runId);
    final execution = _SuiteAttemptExecution(
      workspaceId: workspaceId,
      projectId: projectId,
      engineVersion: engineVersion,
      runStateRoot: runStateRoot,
      context: context,
      runId: runId,
      sessions: _sessions,
      resourceAuthority: _resourceAuthority,
      secretResolver: _secretResolver,
      safetyPolicy: _safetyPolicy,
      redactor: _redactor,
      eventStore: _eventStore,
      runStore: _runStore,
      artifactPublisher: _artifactPublisher,
      utcNow: _utcNow,
    );
    final schedule =
        await CockpitSuiteScheduler(
          executor: execution,
          observer: execution,
          utcNow: _utcNow,
        ).run(
          runId: runId,
          plan: plan,
          cancellation: execution,
          initialExecutions: reservation.executions,
        );
    final finishedAt = _utcNow();
    final report = const CockpitSuiteReportAssembler().assemble(
      projectId: projectId,
      workspaceId: workspaceId,
      runId: runId,
      plan: plan,
      schedule: schedule,
      startedAt: reservation.startedAt,
      finishedAt: finishedAt,
      environment: <String, Object?>{
        'engineVersion': engineVersion,
        'requiredFeatures': submission.requiredFeatures,
      },
    );
    final reportRoot = p.join(runStateRoot, 'runs', runId, 'report');
    final files = await const CockpitSuiteReportWriter().write(
      report: report,
      runRoot: reportRoot,
    );
    final reportArtifacts = _artifactPublisher == null
        ? const <CockpitArtifactResource>[]
        : await _artifactPublisher.publishSuiteReport(
            report: report,
            reportRoot: reportRoot,
            deadline: context.deadline,
            cancellation: context.cancellation,
          );
    final failure = _reportFailure(report);
    await _eventStore.append(
      runId,
      CockpitWorkerEventDraft(
        kind: 'report.completed',
        entityKind: CockpitRunEventEntityKind.report,
        outcome: report.outcome,
        stability: report.stability,
        failure: failure,
        artifacts: reportArtifacts
            .map((artifact) => artifact.reference)
            .toList(growable: false),
      ),
    );
    await _eventStore.append(
      runId,
      CockpitWorkerEventDraft(
        kind: 'suite.completed',
        entityKind: CockpitRunEventEntityKind.suite,
        lifecycle: CockpitRunLifecycle.completed,
        outcome: report.outcome,
        stability: report.stability,
        failure: failure,
      ),
    );
    await _eventStore.append(
      runId,
      CockpitWorkerEventDraft(
        kind: 'run.completed',
        entityKind: CockpitRunEventEntityKind.run,
        lifecycle: CockpitRunLifecycle.completed,
        outcome: report.outcome,
        stability: report.stability,
        failure: failure,
      ),
    );
    final output = <String, Object?>{
      'runId': runId,
      'report': report.toJson(),
      'reportFiles': <String, Object?>{
        for (final entry in files.paths.entries)
          entry.key.name: p.basename(entry.value),
      },
      'reportArtifacts': reportArtifacts
          .map((artifact) => artifact.toJson())
          .toList(growable: false),
    };
    await _runStore.complete(runId: runId, output: output);
    return output;
  }

  Future<void> _initializeEvents(String runId) async {
    final existing = await _eventStore.eventsForRun(runId);
    if (existing.isNotEmpty) return;
    for (final entity in const <CockpitRunEventEntityKind>[
      CockpitRunEventEntityKind.run,
      CockpitRunEventEntityKind.suite,
    ]) {
      await _eventStore.append(
        runId,
        CockpitWorkerEventDraft(
          kind: '${entity.wireName}.queued',
          entityKind: entity,
          lifecycle: CockpitRunLifecycle.queued,
        ),
      );
    }
    for (final entity in const <CockpitRunEventEntityKind>[
      CockpitRunEventEntityKind.run,
      CockpitRunEventEntityKind.suite,
    ]) {
      await _eventStore.append(
        runId,
        CockpitWorkerEventDraft(
          kind: '${entity.wireName}.running',
          entityKind: entity,
          lifecycle: CockpitRunLifecycle.running,
        ),
      );
    }
  }

  String _fingerprint(
    CockpitRunSubmission submission,
    CockpitSuiteExecutionPlan plan,
  ) => sha256
      .convert(
        utf8.encode(
          jsonEncode(
            _canonical(<String, Object?>{
              'submission': submission.toJson(),
              'plan': plan.toJson(),
            }),
          ),
        ),
      )
      .toString();

  Duration _resourceTtl(DateTime deadline) {
    final remaining = deadline.difference(_utcNow());
    if (remaining < const Duration(seconds: 1)) {
      return const Duration(seconds: 1);
    }
    return remaining > const Duration(minutes: 5)
        ? const Duration(minutes: 5)
        : remaining;
  }
}

final class _SuiteAttemptExecution
    implements
        CockpitSuiteAttemptExecutor,
        CockpitSuiteSchedulerObserver,
        CockpitSuiteCancellation {
  _SuiteAttemptExecution({
    required this.workspaceId,
    required this.projectId,
    required this.engineVersion,
    required this.runStateRoot,
    required this.context,
    required this.runId,
    required CockpitWorkerSessionProvider sessions,
    required CockpitWorkerResourceAuthorityClient resourceAuthority,
    required CockpitTestSecretResolver secretResolver,
    required CockpitTestSafetyPolicy safetyPolicy,
    required CockpitWorkerLogRedactor redactor,
    required CockpitWorkerRunEventStore eventStore,
    required CockpitWorkerSuiteRunStore runStore,
    required CockpitWorkerArtifactPublisher? artifactPublisher,
    required DateTime Function() utcNow,
  }) : _sessions = sessions,
       _resourceAuthority = resourceAuthority,
       _secretResolver = secretResolver,
       _safetyPolicy = safetyPolicy,
       _redactor = redactor,
       _eventStore = eventStore,
       _runStore = runStore,
       _artifactPublisher = artifactPublisher,
       _utcNow = utcNow;

  final String workspaceId;
  final String projectId;
  final String engineVersion;
  final String runStateRoot;
  final CockpitWorkspaceOperationContext context;
  final String runId;
  final CockpitWorkerSessionProvider _sessions;
  final CockpitWorkerResourceAuthorityClient _resourceAuthority;
  final CockpitTestSecretResolver _secretResolver;
  final CockpitTestSafetyPolicy _safetyPolicy;
  final CockpitWorkerLogRedactor _redactor;
  final CockpitWorkerRunEventStore _eventStore;
  final CockpitWorkerSuiteRunStore _runStore;
  final CockpitWorkerArtifactPublisher? _artifactPublisher;
  final DateTime Function() _utcNow;

  @override
  bool get isCancelled => context.cancellation.isCancelled;

  @override
  Future<void> get whenCancelled => context.cancellation.whenCancelled;

  @override
  Future<void> nodeStarted(
    CockpitSuitePlanNode node,
    DateTime startedAt,
  ) async {
    await _eventStore.append(
      runId,
      CockpitWorkerEventDraft(
        kind: 'case.running',
        entityKind: CockpitRunEventEntityKind.testCase,
        caseId: node.compiledCase.testCase.id,
        targetId: node.targetId,
        requestedPlane: node.compiledCase.testCase.target.plane,
      ),
    );
  }

  @override
  Future<void> attemptCompleted(
    CockpitSuitePlanNode node,
    CockpitTestAttemptReport attempt,
  ) async {
    final existing = await _eventStore.eventsForRun(runId);
    if (existing.any(
      (event) =>
          event.entityKind == CockpitRunEventEntityKind.attempt &&
          event.attemptId == attempt.attemptId &&
          event.outcome != null,
    )) {
      return;
    }
    await _eventStore.append(
      runId,
      CockpitWorkerEventDraft(
        kind: 'attempt.completed',
        entityKind: CockpitRunEventEntityKind.attempt,
        caseId: node.compiledCase.testCase.id,
        attemptId: attempt.attemptId,
        outcome: attempt.outcome,
        targetId: attempt.targetId,
        requestedPlane: node.compiledCase.testCase.target.plane,
        failure: attempt.failure,
        artifacts: attempt.artifacts,
      ),
    );
  }

  @override
  Future<void> nodeCompleted(
    CockpitSuitePlanNode node,
    CockpitSuiteNodeExecution execution,
  ) async {
    await _runStore.recordExecution(runId: runId, execution: execution);
    if (execution.kind != CockpitSuitePlanNodeKind.testCase) return;
    final failure =
        execution.attempts.lastOrNull?.failure ??
        _outcomeFailure(execution.outcome, 'Suite case did not pass.');
    await _eventStore.append(
      runId,
      CockpitWorkerEventDraft(
        kind: 'case.completed',
        entityKind: CockpitRunEventEntityKind.testCase,
        caseId: node.compiledCase.testCase.id,
        attemptId: execution.attempts.lastOrNull?.attemptId,
        outcome: execution.outcome,
        stability: execution.stability,
        failure: failure,
      ),
    );
  }

  @override
  Future<CockpitTestAttemptReport> execute({
    required CockpitSuitePlanNode node,
    required String runId,
    required String attemptId,
    required int attemptNumber,
    required CockpitSuiteCancellation cancellation,
  }) async {
    final compiled = node.compiledCase;
    final testCase = compiled.testCase;
    final plan = CockpitTestVariableBinder().bind(
      compiled,
      inputs: node.inputs,
    );
    final session = await _sessions.selectHealthySession(
      targetId: node.targetId,
      requirements: testCase.target,
    );
    final ttl = _resourceTtl();
    final holderDigest = sha256
        .convert(utf8.encode('$runId\u0000${node.nodeId}\u0000$attemptId'))
        .toString();
    final scope = await CockpitWorkerResourceScope.acquire(
      authority: _resourceAuthority,
      cancellation: context.cancellation,
      requests: <CockpitWorkerResourceRequest>[
        CockpitWorkerResourceRequest(
          resourceKind: CockpitLeaseResourceKind.device,
          resourceId: session.deviceResourceId,
          ttl: ttl,
        ),
        for (final kind in const <CockpitLeaseResourceKind>[
          CockpitLeaseResourceKind.session,
          CockpitLeaseResourceKind.capture,
          CockpitLeaseResourceKind.recording,
        ])
          CockpitWorkerResourceRequest(
            resourceKind: kind,
            resourceId: session.resourceId,
            ttl: ttl,
          ),
      ],
      workspaceId: workspaceId,
      holderId: 'suite-attempt-${holderDigest.substring(0, 32)}',
      idempotencyKey: '${context.idempotencyKey}-${node.nodeId}-$attemptNumber',
      deadline: context.deadline,
    );
    void Function()? unregisterForceAbort;
    try {
      await _eventStore.append(
        runId,
        CockpitWorkerEventDraft(
          kind: 'attempt.running',
          entityKind: CockpitRunEventEntityKind.attempt,
          caseId: testCase.id,
          attemptId: attemptId,
          targetId: session.targetId,
          requestedPlane: testCase.target.plane,
        ),
      );
      if (!await session.healthCheck()) {
        throw const FormatException(
          'Selected automation session is unhealthy.',
        );
      }
      final control = CockpitCaseExecutionControl(
        forceAbort: session.forceAbort,
      );
      if (session.forceAbort case final forceAbort?) {
        unregisterForceAbort = context.cancellation.registerForceAbort(
          forceAbort,
        );
      }
      unawaited(
        context.cancellation.whenCancelled.then((_) => control.cancel()),
      );
      final attemptRoot = p.join(
        runStateRoot,
        'runs',
        runId,
        'cases',
        testCase.id,
        'attempts',
        attemptId,
      );
      await Directory(attemptRoot).create(recursive: true);
      final scanner = CockpitCaseAttemptRedactionScanner(
        runStateRoot: runStateRoot,
        redactor: _redactor,
        deadline: context.deadline,
        isCancelled: () => context.cancellation.isCancelled,
        utcNow: _utcNow,
      );
      final runner = CockpitCaseRunner(
        automationAdapter: session.automationAdapter,
        captureAdapter: session.captureAdapter,
        recordingAdapter: session.recordingAdapter,
        lowerer: session.lowerer,
        secretResolver: _secretResolver,
        safetyPolicy: _safetyPolicy,
        bundlePrePublicationValidator: scanner.validateForPublication,
      );
      final result = await scope.guard(
        runner.run(
          compiled: compiled,
          preparedPlan: plan,
          context: CockpitTestRunContext(
            projectId: projectId,
            workspaceId: workspaceId,
            runId: runId,
            caseId: testCase.id,
            attemptId: attemptId,
            engineVersion: engineVersion,
          ),
          targetId: session.targetId,
          targetEnvironment: session.environment,
          reportRoot: attemptRoot,
          control: control,
        ),
      );
      await scanner.verify(attemptRoot);
      var artifacts = const <CockpitArtifactResource>[];
      if (_artifactPublisher case final publisher?
          when result.bundlePath != null) {
        artifacts = await publisher.publishAttemptBundle(
          runId: runId,
          caseId: testCase.id,
          attemptId: attemptId,
          bundleRoot: result.bundlePath!,
          deadline: context.deadline,
          cancellation: context.cancellation,
        );
      }
      await _appendResultEvents(result, artifacts);
      return _attemptReport(result, attemptNumber, artifacts);
    } finally {
      unregisterForceAbort?.call();
      await scope.close(cancel: cancellation.isCancelled);
    }
  }

  Future<void> _appendResultEvents(
    CockpitTestAttemptResult result,
    List<CockpitArtifactResource> artifacts,
  ) async {
    for (final step in result.steps) {
      await _eventStore.append(
        runId,
        CockpitWorkerEventDraft(
          kind: 'step.${step.status.name}',
          entityKind: CockpitRunEventEntityKind.step,
          caseId: result.context.caseId,
          attemptId: result.context.attemptId,
          stepExecutionId: step.executionId,
          stepStatus: step.status,
          sourceLocation: step.sourceLocation,
          targetId: result.targetId,
          requestedPlane: step.requestedPlane ?? result.requestedPlane,
          actualPlane: step.actualPlane ?? result.actualPlane,
          driverId: step.driverId,
          degradation: step.degradationReason,
          locatorSummary:
              step.locatorResolution?.toJson() ?? const <String, Object?>{},
          failure: step.error == null
              ? null
              : CockpitFailure(primary: _apiError(step.error!)),
          artifacts: artifacts
              .where((artifact) => artifact.stepExecutionId == step.executionId)
              .map((artifact) => artifact.reference)
              .toList(growable: false),
        ),
      );
    }
    final outcome = _runOutcome(result.outcome);
    final failure = result.primaryError == null
        ? null
        : CockpitFailure(
            primary: _apiError(result.primaryError!),
            warnings: <CockpitApiWarning>[
              for (final warning in result.cleanupErrors)
                CockpitApiWarning(
                  stage: CockpitWarningStage.cleanup,
                  error: _apiError(warning),
                ),
            ],
          );
    await _eventStore.append(
      runId,
      CockpitWorkerEventDraft(
        kind: 'attempt.completed',
        entityKind: CockpitRunEventEntityKind.attempt,
        caseId: result.context.caseId,
        attemptId: result.context.attemptId,
        outcome: outcome,
        targetId: result.targetId,
        requestedPlane: result.requestedPlane,
        actualPlane: result.actualPlane,
        failure: failure,
        artifacts: artifacts
            .where((artifact) => artifact.kind == 'attempt.manifest')
            .map((artifact) => artifact.reference)
            .toList(growable: false),
      ),
    );
  }

  CockpitTestAttemptReport _attemptReport(
    CockpitTestAttemptResult result,
    int attemptNumber,
    List<CockpitArtifactResource> artifacts,
  ) {
    final outcome = _runOutcome(result.outcome);
    return CockpitTestAttemptReport(
      attemptId: result.context.attemptId,
      number: attemptNumber,
      outcome: outcome,
      startedAt: result.startedAt,
      finishedAt: result.finishedAt,
      durationMs: result.durationMs,
      targetId: result.targetId,
      failure: result.primaryError == null
          ? null
          : CockpitFailure(
              primary: _apiError(result.primaryError!),
              warnings: <CockpitApiWarning>[
                for (final warning in result.cleanupErrors)
                  CockpitApiWarning(
                    stage: CockpitWarningStage.cleanup,
                    error: _apiError(warning),
                  ),
              ],
            ),
      artifacts: artifacts.map((artifact) => artifact.reference),
    );
  }

  Duration _resourceTtl() {
    final remaining = context.deadline.difference(_utcNow());
    if (remaining < const Duration(seconds: 1)) {
      return const Duration(seconds: 1);
    }
    return remaining > const Duration(minutes: 5)
        ? const Duration(minutes: 5)
        : remaining;
  }
}

CockpitRunOutcome _runOutcome(CockpitTestOutcome outcome) => switch (outcome) {
  CockpitTestOutcome.passed => CockpitRunOutcome.passed,
  CockpitTestOutcome.failed => CockpitRunOutcome.failed,
  CockpitTestOutcome.blocked => CockpitRunOutcome.blocked,
  CockpitTestOutcome.skipped => CockpitRunOutcome.skipped,
  CockpitTestOutcome.cancelled => CockpitRunOutcome.cancelled,
  CockpitTestOutcome.interrupted => CockpitRunOutcome.interrupted,
  CockpitTestOutcome.internalError => CockpitRunOutcome.internalError,
};

CockpitApiError _apiError(CockpitTestError error) => CockpitApiError(
  code: switch (error.code) {
    CockpitTestErrorCode.assertionFailed => CockpitErrorCode.assertionFailed,
    CockpitTestErrorCode.cancelled => CockpitErrorCode.cancelled,
    CockpitTestErrorCode.driverFailed ||
    CockpitTestErrorCode.hardShutdown => CockpitErrorCode.driverUnavailable,
    CockpitTestErrorCode.evidenceFailed ||
    CockpitTestErrorCode.recordingFailed ||
    CockpitTestErrorCode.bundlePublicationFailed ||
    CockpitTestErrorCode.bundleIntegrityFailed =>
      CockpitErrorCode.evidenceFailed,
    CockpitTestErrorCode.internalFailure => CockpitErrorCode.internalError,
    _ => CockpitErrorCode.invalidRequest,
  },
  category: switch (error.code) {
    CockpitTestErrorCode.assertionFailed => CockpitErrorCategory.assertion,
    CockpitTestErrorCode.cancelled => CockpitErrorCategory.cancelled,
    CockpitTestErrorCode.driverFailed ||
    CockpitTestErrorCode.hardShutdown => CockpitErrorCategory.driver,
    CockpitTestErrorCode.evidenceFailed ||
    CockpitTestErrorCode.recordingFailed ||
    CockpitTestErrorCode.bundlePublicationFailed ||
    CockpitTestErrorCode.bundleIntegrityFailed => CockpitErrorCategory.evidence,
    CockpitTestErrorCode.internalFailure => CockpitErrorCategory.internal,
    _ => CockpitErrorCategory.invalidInput,
  },
  message: error.message,
  retryable: const <CockpitTestErrorCode>{
    CockpitTestErrorCode.timeout,
    CockpitTestErrorCode.hardShutdown,
    CockpitTestErrorCode.driverFailed,
    CockpitTestErrorCode.recordingFailed,
    CockpitTestErrorCode.evidenceFailed,
    CockpitTestErrorCode.bundlePublicationFailed,
    CockpitTestErrorCode.bundleIntegrityFailed,
  }.contains(error.code),
  responsibleLayer:
      error.code == CockpitTestErrorCode.driverFailed ||
          error.code == CockpitTestErrorCode.recordingFailed
      ? CockpitResponsibleLayer.driver
      : CockpitResponsibleLayer.worker,
  redactedDetails: <String, Object?>{
    ...error.details,
    if (error.path != null) 'path': error.path,
    if (error.stepId != null) 'stepId': error.stepId,
    if (error.location != null) 'location': error.location!.toJson(),
  },
);

CockpitFailure? _outcomeFailure(CockpitRunOutcome outcome, String message) {
  if (outcome == CockpitRunOutcome.passed ||
      outcome == CockpitRunOutcome.skipped) {
    return null;
  }
  return CockpitFailure(
    primary: CockpitApiError(
      code: outcome == CockpitRunOutcome.cancelled
          ? CockpitErrorCode.cancelled
          : 'suiteCaseFailed',
      category: outcome == CockpitRunOutcome.cancelled
          ? CockpitErrorCategory.cancelled
          : CockpitErrorCategory.assertion,
      message: message,
      retryable:
          outcome == CockpitRunOutcome.interrupted ||
          outcome == CockpitRunOutcome.internalError,
      responsibleLayer: CockpitResponsibleLayer.worker,
    ),
  );
}

CockpitFailure? _reportFailure(CockpitTestSuiteReport report) {
  if (report.outcome == CockpitRunOutcome.passed) return null;
  return report.cases
          .expand((testCase) => testCase.attempts)
          .map((attempt) => attempt.failure)
          .whereType<CockpitFailure>()
          .firstOrNull ??
      _outcomeFailure(report.outcome, 'Suite execution did not pass.');
}

Object? _canonical(Object? value) {
  if (value is List<Object?>) {
    return value.map(_canonical).toList(growable: false);
  }
  if (value is Map<Object?, Object?>) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonical(value[key]),
    };
  }
  return value;
}
