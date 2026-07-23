import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../application/cockpit_application_service_exception.dart';
import '../runner/cockpit_case_execution_control.dart';
import '../runner/cockpit_case_runner.dart';
import '../suite/cockpit_suite_compiler.dart';
import '../suite/cockpit_suite_execution_plan.dart';
import '../suite/cockpit_suite_report_assembler.dart';
import '../suite/cockpit_suite_report_writer.dart';
import '../suite/cockpit_suite_row_attempt_executor.dart';
import '../suite/cockpit_suite_scheduler.dart';
import '../test/cockpit_test_document_compiler.dart';
import '../test/cockpit_test_safety_policy.dart';
import '../test/cockpit_test_secret_resolver.dart';
import '../test/cockpit_test_variable_binder.dart';
import 'cockpit_case_run_adapter.dart';
import 'cockpit_json_rpc_peer.dart';
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
        cancellationGrace: _cancellationGrace(context.deadline),
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
      plan: plan,
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
    late final CockpitSuiteScheduleResult schedule;
    try {
      schedule =
          await CockpitSuiteScheduler(
            executor: CockpitSuiteRowAttemptExecutor(
              plan: plan,
              delegate: execution,
              onAttemptFinished: execution.closeRowResourceBoundary,
              utcNow: _utcNow,
            ),
            observer: execution,
            utcNow: _utcNow,
          ).run(
            runId: runId,
            plan: plan,
            cancellation: execution,
            initialExecutions: reservation.executions,
          );
    } finally {
      await execution.closeResourceBoundaries();
    }
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
    await execution.publishCaseCompletions(plan, report);
    final reportRoot = p.join(runStateRoot, 'runs', runId, 'report');
    CockpitSuiteReportFiles? files;
    var reportArtifacts = const <CockpitArtifactResource>[];
    CockpitFailure? finalizationFailure;
    try {
      files = await const CockpitSuiteReportWriter().write(
        report: report,
        runRoot: reportRoot,
      );
      if (_artifactPublisher case final publisher?) {
        reportArtifacts = await publisher.publishSuiteReport(
          report: report,
          reportRoot: reportRoot,
          deadline: _utcNow().add(const Duration(minutes: 1)),
          cancellation: CockpitRpcCancellation.detached(),
        );
      }
    } on Object {
      finalizationFailure = _suiteFinalizationFailure();
    }
    final terminalOutcome = finalizationFailure == null
        ? report.outcome
        : CockpitRunOutcome.internalError;
    final failure = _mergeFailures(_reportFailure(report), finalizationFailure);
    await _eventStore.append(
      runId,
      CockpitWorkerEventDraft(
        kind: 'report.completed',
        entityKind: CockpitRunEventEntityKind.report,
        outcome: terminalOutcome,
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
        outcome: terminalOutcome,
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
        outcome: terminalOutcome,
        stability: report.stability,
        failure: failure,
      ),
    );
    final output = <String, Object?>{
      'runId': runId,
      'outcome': terminalOutcome.name,
      'report': report.toJson(),
      'reportFiles': <String, Object?>{
        for (final entry
            in files?.paths.entries ??
                const <MapEntry<CockpitTestReportFormat, String>>[])
          entry.key.name: p.basename(entry.value),
      },
      'reportArtifacts': reportArtifacts
          .map((artifact) => artifact.toJson())
          .toList(growable: false),
      if (finalizationFailure != null)
        'finalizationFailure': finalizationFailure.toJson(),
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

  Duration _cancellationGrace(DateTime deadline) {
    final remaining = deadline.difference(_utcNow());
    if (remaining <= Duration.zero) return const Duration(seconds: 1);
    const maximum = Duration(minutes: 5);
    return remaining < maximum ? remaining : maximum;
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
    required this.plan,
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
       _utcNow = utcNow,
       _rowSessionAffinity = CockpitSuiteRowSessionAffinity(plan);

  final String workspaceId;
  final String projectId;
  final String engineVersion;
  final String runStateRoot;
  final CockpitWorkspaceOperationContext context;
  final String runId;
  final CockpitSuiteExecutionPlan plan;
  final CockpitWorkerSessionProvider _sessions;
  final CockpitWorkerResourceAuthorityClient _resourceAuthority;
  final CockpitTestSecretResolver _secretResolver;
  final CockpitTestSafetyPolicy _safetyPolicy;
  final CockpitWorkerLogRedactor _redactor;
  final CockpitWorkerRunEventStore _eventStore;
  final CockpitWorkerSuiteRunStore _runStore;
  final CockpitWorkerArtifactPublisher? _artifactPublisher;
  final DateTime Function() _utcNow;
  final CockpitSuiteRowSessionAffinity _rowSessionAffinity;
  final Map<String, Map<String, Future<_SuiteRowResourceBoundary>>>
  _rowBoundaries = <String, Map<String, Future<_SuiteRowResourceBoundary>>>{};

  @override
  bool get isCancelled => context.cancellation.isCancelled;

  @override
  Future<void> get whenCancelled => context.cancellation.whenCancelled;

  @override
  Future<void> nodeStarted(
    CockpitSuitePlanNode node,
    DateTime startedAt,
  ) async {
    if (node.kind != CockpitSuitePlanNodeKind.testCase) return;
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
    if (node.kind != CockpitSuitePlanNodeKind.testCase) return;
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
  ) => _runStore.recordExecution(runId: runId, execution: execution);

  @override
  Future<CockpitTestAttemptReport> execute({
    required CockpitSuitePlanNode node,
    required String runId,
    required String attemptId,
    required int attemptNumber,
    required CockpitSuiteCancellation cancellation,
  }) async {
    if (node.kind == CockpitSuitePlanNodeKind.isolation) {
      return _executeIsolation(
        node: node,
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        cancellation: cancellation,
      );
    }
    final compiled = node.compiledCase;
    final testCase = compiled.testCase;
    final plan = CockpitTestVariableBinder().bind(
      compiled,
      inputs: node.inputs,
    );
    late final CockpitWorkerHealthySession session;
    late final _SuiteRowResourceBoundary? rowBoundary;
    final startedAt = _utcNow();
    try {
      session = await _sessions.selectHealthySession(
        targetId: node.targetId,
        requirements: testCase.target,
      );
      rowBoundary = await _rowResourceBoundary(node, session);
    } on CockpitApplicationServiceException catch (error) {
      if (error.code != 'suiteSessionDrift') rethrow;
      return _suiteRuntimeFailure(
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        startedAt: startedAt,
        targetId: node.targetId ?? 'unassigned',
        code: error.code,
        message: error.message,
        category: CockpitErrorCategory.environment,
        retryable: false,
        details: error.details,
      );
    }
    final ttl = _resourceTtl();
    final holderDigest = sha256
        .convert(utf8.encode('$runId\u0000${node.nodeId}\u0000$attemptId'))
        .toString();
    final operationCancellation = node.alwaysRun
        ? CockpitRpcCancellation.detached()
        : context.cancellation;
    final scope = await CockpitWorkerResourceScope.acquire(
      authority: _resourceAuthority,
      cancellation: operationCancellation,
      requests: <CockpitWorkerResourceRequest>[
        if (rowBoundary == null) ...<CockpitWorkerResourceRequest>[
          CockpitWorkerResourceRequest(
            resourceKind: CockpitLeaseResourceKind.device,
            resourceId: session.deviceResourceId,
            ttl: ttl,
          ),
          CockpitWorkerResourceRequest(
            resourceKind: CockpitLeaseResourceKind.session,
            resourceId: session.resourceId,
            ttl: ttl,
          ),
        ],
        for (final kind in const <CockpitLeaseResourceKind>[
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
        unregisterForceAbort = operationCancellation.registerForceAbort(
          forceAbort,
        );
      }
      unawaited(cancellation.whenCancelled.then((_) => control.cancel()));
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
        isCancelled: () => cancellation.isCancelled,
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
      final run = scope.guard(
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
      final result = await (rowBoundary == null
          ? run
          : rowBoundary.scope.guard(run));
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
          cancellation: operationCancellation,
        );
      }
      await _appendResultEvents(
        result,
        artifacts,
        includeAttemptCompletion:
            node.kind != CockpitSuitePlanNodeKind.testCase,
      );
      return _attemptReport(result, attemptNumber, artifacts);
    } finally {
      unregisterForceAbort?.call();
      await scope.close(cancel: cancellation.isCancelled);
    }
  }

  Future<CockpitTestAttemptReport> _executeIsolation({
    required CockpitSuitePlanNode node,
    required String attemptId,
    required int attemptNumber,
    required CockpitSuiteCancellation cancellation,
  }) async {
    final startedAt = _utcNow();
    if (cancellation.isCancelled) {
      return _suiteRuntimeFailure(
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        startedAt: startedAt,
        targetId: node.targetId ?? 'unassigned',
        code: CockpitErrorCode.cancelled,
        message: 'Suite isolation was cancelled.',
        category: CockpitErrorCategory.cancelled,
        retryable: false,
      );
    }
    final isolation = node.isolation!;
    final session = await _sessions.selectHealthySession(
      targetId: node.targetId,
      requirements: node.compiledCase.testCase.target,
    );
    final rowBoundary = await _rowResourceBoundary(node, session);
    if (rowBoundary == null) {
      throw StateError('Suite isolation is missing its case row boundary.');
    }
    if (isolation == CockpitTestSuiteIsolation.sharedSession) {
      final finishedAt = _utcNow();
      return CockpitTestAttemptReport(
        attemptId: attemptId,
        number: attemptNumber,
        outcome: CockpitRunOutcome.passed,
        startedAt: startedAt,
        finishedAt: finishedAt,
        durationMs: finishedAt.difference(startedAt).inMilliseconds,
        targetId: session.targetId,
      );
    }
    final isolate = session.isolate;
    if (isolate == null) {
      return _suiteRuntimeFailure(
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        startedAt: startedAt,
        targetId: session.targetId,
        code: 'suiteIsolationUnsupported',
        message:
            '${isolation.name} is not supported by the selected driver session.',
        category: CockpitErrorCategory.unsupported,
        retryable: false,
      );
    }
    void Function()? unregisterForceAbort;
    try {
      if (session.forceAbort case final forceAbort?) {
        unregisterForceAbort = context.cancellation.registerForceAbort(
          forceAbort,
        );
      }
      await rowBoundary.scope.guard(isolate(isolation, context.deadline));
      if (cancellation.isCancelled) {
        return _suiteRuntimeFailure(
          attemptId: attemptId,
          attemptNumber: attemptNumber,
          startedAt: startedAt,
          targetId: session.targetId,
          code: CockpitErrorCode.cancelled,
          message: 'Suite isolation was cancelled.',
          category: CockpitErrorCategory.cancelled,
          retryable: false,
        );
      }
      final refreshed = await _sessions.selectHealthySession(
        targetId: node.targetId,
        requirements: node.compiledCase.testCase.target,
      );
      await _rowResourceBoundary(node, refreshed);
    } on CockpitApplicationServiceException catch (error) {
      if (cancellation.isCancelled) {
        return _suiteRuntimeFailure(
          attemptId: attemptId,
          attemptNumber: attemptNumber,
          startedAt: startedAt,
          targetId: session.targetId,
          code: CockpitErrorCode.cancelled,
          message: 'Suite isolation was cancelled.',
          category: CockpitErrorCategory.cancelled,
          retryable: false,
        );
      }
      return _suiteRuntimeFailure(
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        startedAt: startedAt,
        targetId: session.targetId,
        code: error.code,
        message: error.message,
        category: error.code == 'suiteIsolationUnsupported'
            ? CockpitErrorCategory.unsupported
            : CockpitErrorCategory.environment,
        retryable: error.code != 'suiteIsolationUnsupported',
        details: error.details,
      );
    } on TimeoutException {
      if (cancellation.isCancelled) {
        return _suiteRuntimeFailure(
          attemptId: attemptId,
          attemptNumber: attemptNumber,
          startedAt: startedAt,
          targetId: session.targetId,
          code: CockpitErrorCode.cancelled,
          message: 'Suite isolation was cancelled.',
          category: CockpitErrorCategory.cancelled,
          retryable: false,
        );
      }
      return _suiteRuntimeFailure(
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        startedAt: startedAt,
        targetId: session.targetId,
        code: CockpitErrorCode.interrupted,
        message: 'Suite isolation exceeded the run deadline.',
        category: CockpitErrorCategory.interrupted,
        retryable: true,
      );
    } on Object {
      if (!cancellation.isCancelled) rethrow;
      return _suiteRuntimeFailure(
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        startedAt: startedAt,
        targetId: session.targetId,
        code: CockpitErrorCode.cancelled,
        message: 'Suite isolation was cancelled.',
        category: CockpitErrorCategory.cancelled,
        retryable: false,
      );
    } finally {
      unregisterForceAbort?.call();
    }
    final finishedAt = _utcNow();
    return CockpitTestAttemptReport(
      attemptId: attemptId,
      number: attemptNumber,
      outcome: CockpitRunOutcome.passed,
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationMs: finishedAt.difference(startedAt).inMilliseconds,
      targetId: session.targetId,
    );
  }

  Future<_SuiteRowResourceBoundary?> _rowResourceBoundary(
    CockpitSuitePlanNode node,
    CockpitWorkerHealthySession session,
  ) async {
    final caseNodeId = node.caseNodeId;
    if (caseNodeId == null) return null;
    final boundaryResourceId = _rowSessionAffinity.resolveBoundaryResourceId(
      node,
      session.resourceId,
    );
    final boundaries = _rowBoundaries.putIfAbsent(
      caseNodeId,
      () => <String, Future<_SuiteRowResourceBoundary>>{},
    );
    return boundaries.putIfAbsent(
      boundaryResourceId,
      () => _acquireRowResourceBoundary(caseNodeId, session),
    );
  }

  Future<_SuiteRowResourceBoundary> _acquireRowResourceBoundary(
    String caseNodeId,
    CockpitWorkerHealthySession session,
  ) async {
    final digest = sha256
        .convert(
          utf8.encode('$runId\u0000$caseNodeId\u0000${session.resourceId}'),
        )
        .toString();
    final scope = await CockpitWorkerResourceScope.acquire(
      authority: _resourceAuthority,
      cancellation: CockpitRpcCancellation.detached(),
      requests: <CockpitWorkerResourceRequest>[
        CockpitWorkerResourceRequest(
          resourceKind: CockpitLeaseResourceKind.device,
          resourceId: session.deviceResourceId,
          ttl: _resourceTtl(),
        ),
        CockpitWorkerResourceRequest(
          resourceKind: CockpitLeaseResourceKind.session,
          resourceId: session.resourceId,
          ttl: _resourceTtl(),
        ),
      ],
      workspaceId: workspaceId,
      holderId: 'suite-row-${digest.substring(0, 32)}',
      idempotencyKey:
          '${context.idempotencyKey}-row-${digest.substring(0, 32)}',
      deadline: context.deadline,
    );
    return _SuiteRowResourceBoundary(scope: scope);
  }

  Future<void> closeRowResourceBoundary(CockpitSuitePlanNode caseNode) =>
      _closeRowResourceBoundary(caseNode.nodeId);

  Future<void> _closeRowResourceBoundary(String caseNodeId) async {
    _rowSessionAffinity.release(caseNodeId);
    final boundaries = _rowBoundaries.remove(caseNodeId);
    if (boundaries == null) return;
    for (final pending in boundaries.values) {
      try {
        final boundary = await pending;
        await boundary.scope.close(cancel: context.cancellation.isCancelled);
      } on Object {
        // Lease recovery remains owned by the Supervisor after release failure.
      }
    }
  }

  Future<void> closeResourceBoundaries() async {
    for (final caseNodeId in _rowBoundaries.keys.toList(growable: false)) {
      await _closeRowResourceBoundary(caseNodeId);
    }
  }

  Future<void> publishCaseCompletions(
    CockpitSuiteExecutionPlan plan,
    CockpitTestSuiteReport report,
  ) async {
    final caseNodes = plan.caseNodes.toList(growable: false);
    if (caseNodes.length != report.cases.length) {
      throw StateError('Suite case report projection is incomplete.');
    }
    final existing = await _eventStore.eventsForRun(runId);
    final completedAttemptIds = existing
        .where(
          (event) =>
              event.entityKind == CockpitRunEventEntityKind.attempt &&
              event.outcome != null &&
              event.attemptId != null,
        )
        .map((event) => event.attemptId!)
        .toSet();
    for (var index = 0; index < caseNodes.length; index += 1) {
      final node = caseNodes[index];
      final testCase = report.cases[index];
      for (final attempt in testCase.attempts) {
        if (!completedAttemptIds.add(attempt.attemptId)) continue;
        await _eventStore.append(
          runId,
          CockpitWorkerEventDraft(
            kind: 'attempt.completed',
            entityKind: CockpitRunEventEntityKind.attempt,
            caseId: testCase.caseId,
            attemptId: attempt.attemptId,
            outcome: attempt.outcome,
            targetId: attempt.targetId,
            requestedPlane: node.compiledCase.testCase.target.plane,
            failure: attempt.failure,
            artifacts: attempt.artifacts,
          ),
        );
      }
      final attemptId = testCase.attempts.lastOrNull?.attemptId;
      final alreadyCompleted = existing.any(
        (event) =>
            event.kind == 'case.completed' &&
            event.entityKind == CockpitRunEventEntityKind.testCase &&
            event.caseId == testCase.caseId &&
            event.attemptId == attemptId &&
            event.outcome == testCase.outcome,
      );
      if (alreadyCompleted) continue;
      await _eventStore.append(
        runId,
        CockpitWorkerEventDraft(
          kind: 'case.completed',
          entityKind: CockpitRunEventEntityKind.testCase,
          caseId: testCase.caseId,
          attemptId: attemptId,
          outcome: testCase.outcome,
          stability: testCase.stability,
          targetId: testCase.targetId,
          requestedPlane: node.compiledCase.testCase.target.plane,
          failure:
              testCase.attempts.lastOrNull?.failure ??
              _outcomeFailure(testCase.outcome, 'Suite case did not pass.'),
        ),
      );
    }
  }

  CockpitTestAttemptReport _suiteRuntimeFailure({
    required String attemptId,
    required int attemptNumber,
    required DateTime startedAt,
    required String targetId,
    required String code,
    required String message,
    required CockpitErrorCategory category,
    required bool retryable,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    final finishedAt = _utcNow();
    return CockpitTestAttemptReport(
      attemptId: attemptId,
      number: attemptNumber,
      outcome: switch (category) {
        CockpitErrorCategory.cancelled => CockpitRunOutcome.cancelled,
        CockpitErrorCategory.interrupted => CockpitRunOutcome.interrupted,
        _ => CockpitRunOutcome.blocked,
      },
      startedAt: startedAt,
      finishedAt: finishedAt,
      durationMs: finishedAt.difference(startedAt).inMilliseconds,
      targetId: targetId,
      failure: CockpitFailure(
        primary: CockpitApiError(
          code: code,
          category: category,
          message: message,
          retryable: retryable,
          responsibleLayer: CockpitResponsibleLayer.worker,
          redactedDetails: details,
        ),
      ),
    );
  }

  Future<void> _appendResultEvents(
    CockpitTestAttemptResult result,
    List<CockpitArtifactResource> artifacts, {
    required bool includeAttemptCompletion,
  }) async {
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
    if (!includeAttemptCompletion) return;
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

final class _SuiteRowResourceBoundary {
  const _SuiteRowResourceBoundary({required this.scope});

  final CockpitWorkerResourceScope scope;
}

final class CockpitSuiteRowSessionAffinity {
  CockpitSuiteRowSessionAffinity(CockpitSuiteExecutionPlan plan)
    : _caseNodes = <String, CockpitSuitePlanNode>{
        for (final node in plan.caseNodes) node.nodeId: node,
      };

  final Map<String, CockpitSuitePlanNode> _caseNodes;
  final Map<String, String> _primarySessionResourceIds = <String, String>{};

  String resolveBoundaryResourceId(
    CockpitSuitePlanNode node,
    String sessionResourceId,
  ) {
    final caseNodeId = node.caseNodeId;
    if (caseNodeId == null) return sessionResourceId;
    final caseNode = _caseNodes[caseNodeId];
    if (caseNode == null) {
      throw StateError('Suite row references an unknown case node.');
    }
    final usesPrimarySession =
        node.kind == CockpitSuitePlanNodeKind.isolation ||
        node.kind == CockpitSuitePlanNodeKind.testCase ||
        node.targetId == caseNode.targetId;
    if (!usesPrimarySession) return sessionResourceId;
    final primary = _primarySessionResourceIds.putIfAbsent(
      caseNodeId,
      () => sessionResourceId,
    );
    if (primary != sessionResourceId) {
      throw CockpitApplicationServiceException(
        code: 'suiteSessionDrift',
        message: 'A suite case row resolved to a different primary session.',
        details: <String, Object?>{
          'caseNodeId': caseNodeId,
          'expectedSessionResourceId': primary,
          'actualSessionResourceId': sessionResourceId,
        },
      );
    }
    return primary;
  }

  void release(String caseNodeId) {
    _primarySessionResourceIds.remove(caseNodeId);
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
  return report.failure ??
      report.cases
          .expand((testCase) => testCase.attempts)
          .map((attempt) => attempt.failure)
          .whereType<CockpitFailure>()
          .firstOrNull ??
      _outcomeFailure(report.outcome, 'Suite execution did not pass.');
}

CockpitFailure _suiteFinalizationFailure() => CockpitFailure(
  primary: CockpitApiError(
    code: 'suiteReportPublicationFailed',
    category: CockpitErrorCategory.evidence,
    message: 'Suite report finalization or publication failed.',
    retryable: true,
    responsibleLayer: CockpitResponsibleLayer.worker,
  ),
);

CockpitFailure? _mergeFailures(
  CockpitFailure? execution,
  CockpitFailure? finalization,
) {
  if (execution == null) return finalization;
  if (finalization == null) return execution;
  return CockpitFailure(
    primary: execution.primary,
    warnings: <CockpitApiWarning>[
      ...execution.warnings,
      CockpitApiWarning(
        stage: CockpitWarningStage.evidence,
        error: finalization.primary,
      ),
    ],
  );
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
