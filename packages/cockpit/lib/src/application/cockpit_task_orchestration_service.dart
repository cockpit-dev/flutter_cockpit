import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cli/cockpit_control_script.dart';
import '../runner/cockpit_workflow_step.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_app_handle.dart';
import 'cockpit_launch_remote_session_service.dart';
import 'cockpit_platform_app_stopper.dart';
import 'cockpit_query_remote_session_service.dart';
import 'cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_run_remote_control_script_service.dart';
import 'cockpit_run_task_service.dart';
import 'cockpit_task_gate.dart';
import 'cockpit_task_orchestration_result.dart';
import 'cockpit_task_stage.dart';

typedef CockpitTaskOrchestrationFunction =
    Future<CockpitTaskOrchestrationResult> Function(
      CockpitRunTaskRequest request,
    );
typedef CockpitStopLaunchedAppFunction =
    Future<void> Function(CockpitAppHandle app);

final class CockpitTaskOrchestrationService {
  CockpitTaskOrchestrationService({
    CockpitLaunchRemoteSessionService? launchService,
    CockpitQueryRemoteSessionService? queryService,
    CockpitRunRemoteControlScriptService? runScriptService,
    CockpitReadTaskBundleSummaryService? readSummaryService,
    CockpitLaunchTaskFunction? launch,
    CockpitQueryTaskFunction? query,
    CockpitRunTaskScriptFunction? runScript,
    CockpitReadTaskSummaryFunction? readSummary,
    CockpitPlatformAppStopper? platformAppStopper,
    CockpitStopLaunchedAppFunction? stopAutomationApp,
  }) : _launch =
           launch ??
           (launchService ?? CockpitLaunchRemoteSessionService()).launch,
       _query =
           query ?? (queryService ?? CockpitQueryRemoteSessionService()).query,
       _runScript =
           runScript ??
           (runScriptService ?? CockpitRunRemoteControlScriptService()).run,
       _readSummary =
           readSummary ??
           (readSummaryService ?? const CockpitReadTaskBundleSummaryService())
               .read,
       _stopAutomationApp =
           stopAutomationApp ??
           (platformAppStopper ?? CockpitPlatformAppStopper()).stop;

  final CockpitLaunchTaskFunction _launch;
  final CockpitQueryTaskFunction _query;
  final CockpitRunTaskScriptFunction _runScript;
  final CockpitReadTaskSummaryFunction _readSummary;
  final CockpitStopLaunchedAppFunction _stopAutomationApp;

  Future<CockpitTaskOrchestrationResult> orchestrate(
    CockpitRunTaskRequest request,
  ) async {
    final completedStages = <CockpitTaskStage>{CockpitTaskStage.assess};
    final warnings = <String>[];
    var sessionHandle = request.sessionHandle;
    CockpitRemoteSessionStatus? preflightStatus;
    final ownsLaunch = request.launch != null;
    CockpitTaskOrchestrationResult? result;

    try {
      completedStages.add(CockpitTaskStage.bootstrap);
      try {
        if (request.launch != null) {
          final launchResult = await _launch(
            CockpitLaunchRemoteSessionRequest(
              projectDir: request.launch!.projectDir,
              target: request.launch!.target,
              platform: request.launch!.platform,
              deviceId: request.launch!.deviceId,
              sessionPort: request.launch!.sessionPort,
              launchTimeout: request.launch!.launchTimeout,
              persistHandlePath: request.launch!.persistHandlePath,
            ),
          );
          sessionHandle = launchResult.sessionHandle;
          preflightStatus = launchResult.health;
        } else {
          final queryResult = await _query(
            CockpitQueryRemoteSessionRequest(
              sessionHandle: request.sessionHandle,
              sessionHandlePath: request.sessionHandlePath,
            ),
          );
          sessionHandle = queryResult.sessionHandle ?? request.sessionHandle;
          preflightStatus = queryResult.status;
        }
      } on CockpitApplicationServiceException catch (error) {
        result = _blockedResult(
          request: request,
          completedStages: completedStages,
          blockedReason: error.message,
          sessionHandle: sessionHandle,
          preflightStatus: preflightStatus,
          warnings: warnings,
        );
      } on Object catch (error) {
        result = _blockedResult(
          request: request,
          completedStages: completedStages,
          blockedReason: error.toString(),
          sessionHandle: sessionHandle,
          preflightStatus: preflightStatus,
          warnings: warnings,
        );
      }

      if (result == null) {
        completedStages.add(CockpitTaskStage.baseline);
        final script = _withBaseline(request.script, request.baseline);

        completedStages.add(CockpitTaskStage.execute);
        CockpitRunRemoteControlScriptResult? runResult;
        try {
          runResult = await _runScript(
            CockpitRunRemoteControlScriptRequest(
              sessionHandle: sessionHandle,
              sessionHandlePath: sessionHandle == null
                  ? request.sessionHandlePath
                  : null,
              script: script,
              outputRoot: request.outputRoot,
              persistScriptPath: request.persistScriptPath,
            ),
          );
        } on CockpitApplicationServiceException catch (error) {
          result = _blockedResult(
            request: request,
            completedStages: completedStages,
            blockedReason: error.message,
            sessionHandle: sessionHandle,
            preflightStatus: preflightStatus,
            warnings: warnings,
          );
        } on Object catch (error) {
          result = _blockedResult(
            request: request,
            completedStages: completedStages,
            blockedReason: error.toString(),
            sessionHandle: sessionHandle,
            preflightStatus: preflightStatus,
            warnings: warnings,
          );
        }

        if (result == null) {
          completedStages.add(CockpitTaskStage.observe);
          final resolvedRunResult = runResult!;
          CockpitReadTaskBundleSummaryResult? bundleSummary;
          try {
            bundleSummary = await _readBundleSummary(
              resolvedRunResult.bundleDir.path,
            );
          } on CockpitApplicationServiceException catch (error) {
            result = _blockedResult(
              request: request,
              completedStages: completedStages,
              blockedReason: error.message,
              sessionHandle: resolvedRunResult.sessionHandle ?? sessionHandle,
              preflightStatus: preflightStatus,
              warnings: warnings,
            );
          } on Object catch (error) {
            result = _blockedResult(
              request: request,
              completedStages: completedStages,
              blockedReason: error.toString(),
              sessionHandle: resolvedRunResult.sessionHandle ?? sessionHandle,
              preflightStatus: preflightStatus,
              warnings: warnings,
            );
          }

          if (result == null) {
            completedStages
              ..add(CockpitTaskStage.judge)
              ..add(CockpitTaskStage.deliver);
            final resolvedSessionHandle =
                resolvedRunResult.sessionHandle ?? sessionHandle;
            final gates = _buildGates(
              request: request,
              bundleSummary: bundleSummary!,
              sessionHandle: resolvedSessionHandle,
            );
            final classification = _classify(gates);

            result = CockpitTaskOrchestrationResult(
              classification: classification,
              recommendedNextStep: _recommendedNextStep(
                classification,
                gates: gates,
              ),
              completedStages: completedStages,
              gates: gates,
              sessionHandle: resolvedSessionHandle,
              preflightStatus: preflightStatus,
              bundleSummary: bundleSummary,
              warnings: warnings,
            );
          }
        }
      }
    } finally {
      if (ownsLaunch && sessionHandle != null) {
        final cleanupWarning = await _stopLaunchedApp(sessionHandle);
        if (cleanupWarning != null) {
          warnings.add(cleanupWarning);
        }
      }
    }

    final finalizedResult = result;
    if (warnings.isEmpty || finalizedResult.warnings.isNotEmpty) {
      return finalizedResult;
    }
    return CockpitTaskOrchestrationResult(
      classification: finalizedResult.classification,
      recommendedNextStep: finalizedResult.recommendedNextStep,
      completedStages: finalizedResult.completedStages,
      gates: finalizedResult.gates,
      sessionHandle: finalizedResult.sessionHandle,
      preflightStatus: finalizedResult.preflightStatus,
      bundleSummary: finalizedResult.bundleSummary,
      blockedReason: finalizedResult.blockedReason,
      warnings: warnings,
    );
  }

  CockpitTaskOrchestrationResult _blockedResult({
    required CockpitRunTaskRequest request,
    required Set<CockpitTaskStage> completedStages,
    required String blockedReason,
    required CockpitRemoteSessionHandle? sessionHandle,
    required CockpitRemoteSessionStatus? preflightStatus,
    required List<String> warnings,
  }) {
    return CockpitTaskOrchestrationResult(
      classification: CockpitRunTaskClassification.blockedByEnvironment,
      recommendedNextStep: 'needs_relaunch',
      completedStages: completedStages,
      gates: _defaultGates(request, sessionReachable: false),
      sessionHandle: sessionHandle,
      preflightStatus: preflightStatus,
      blockedReason: blockedReason,
      warnings: warnings,
    );
  }

  Map<CockpitTaskGate, bool> _buildGates({
    required CockpitRunTaskRequest request,
    required CockpitReadTaskBundleSummaryResult bundleSummary,
    required CockpitRemoteSessionHandle? sessionHandle,
  }) {
    final screenshotReady =
        !request.requirements.requireScreenshotEvidence ||
        ((bundleSummary.artifactPaths.primaryScreenshotPath?.isNotEmpty ??
                false) ||
            bundleSummary.manifest.deliveryArtifactsReady);
    final recordingReadyOrExplained =
        !request.requirements.requireVideoEvidence ||
        ((bundleSummary.artifactPaths.primaryRecordingPath?.isNotEmpty ??
                false) ||
            bundleSummary.manifest.deliveryVideoReady);
    final deliveryValidated =
        screenshotReady &&
        recordingReadyOrExplained &&
        (!request.requirements.requireScreenshotEvidence ||
            bundleSummary.manifest.deliveryArtifactsReady);
    final acceptanceEvidenceReadable =
        bundleSummary.baselineEvidence != null &&
        bundleSummary.acceptanceEvidence != null &&
        bundleSummary.acceptanceDelta != null &&
        bundleSummary.baselineEvidence!.hasComparableSignals &&
        bundleSummary.acceptanceEvidence!.hasComparableSignals;
    final finalAssertionPassed =
        bundleSummary.manifest.status != CockpitTaskStatus.failed &&
        bundleSummary.manifest.runtimeErrorCount == 0;
    final intendedPlaneWorked = _gateValueOrDefault(
      bundleSummary.gateSummary,
      CockpitTaskGate.intendedPlaneWorked,
      bundleSummary.manifest.fallbackCount == 0,
    );
    final deliveryReadable = _gateValueOrDefault(
      bundleSummary.gateSummary,
      CockpitTaskGate.deliveryReadable,
      bundleSummary.acceptanceMarkdown.trim().isNotEmpty,
    );
    final fallbackAcceptable = _gateValueOrDefault(
      bundleSummary.gateSummary,
      CockpitTaskGate.fallbackAcceptable,
      intendedPlaneWorked || (finalAssertionPassed && deliveryReadable),
    );

    return _defaultGates(
      request,
      sessionReachable: sessionHandle != null,
      targetReachable: _gateValueOrDefault(
        bundleSummary.gateSummary,
        CockpitTaskGate.targetReachable,
        sessionHandle != null,
      ),
      baselineCollected: _baselineCollected(request, bundleSummary),
      executionFinished: true,
      bundleWritten: true,
      intendedPlaneWorked: intendedPlaneWorked,
      fallbackAcceptable: fallbackAcceptable,
      postconditionsSatisfied: _gateValueOrDefault(
        bundleSummary.gateSummary,
        CockpitTaskGate.postconditionsSatisfied,
        finalAssertionPassed,
      ),
      artifactsReady: _gateValueOrDefault(
        bundleSummary.gateSummary,
        CockpitTaskGate.artifactsReady,
        deliveryValidated,
      ),
      logsCollected: _gateValueOrDefault(
        bundleSummary.gateSummary,
        CockpitTaskGate.logsCollected,
        true,
      ),
      deliveryReadable: deliveryReadable,
      deliveryValidated: deliveryValidated,
      acceptanceEvidenceReadable: acceptanceEvidenceReadable,
      screenshotReady: screenshotReady,
      recordingReadyOrExplained: recordingReadyOrExplained,
      finalAssertionPassed: finalAssertionPassed,
    );
  }

  Map<CockpitTaskGate, bool> _defaultGates(
    CockpitRunTaskRequest request, {
    bool sessionReachable = false,
    bool targetReachable = false,
    bool baselineCollected = false,
    bool executionFinished = false,
    bool bundleWritten = false,
    bool intendedPlaneWorked = true,
    bool fallbackAcceptable = true,
    bool postconditionsSatisfied = false,
    bool artifactsReady = false,
    bool logsCollected = true,
    bool deliveryReadable = false,
    bool deliveryValidated = false,
    bool acceptanceEvidenceReadable = false,
    bool? screenshotReady,
    bool? recordingReadyOrExplained,
    bool finalAssertionPassed = false,
  }) {
    return <CockpitTaskGate, bool>{
      CockpitTaskGate.sessionReachable: sessionReachable,
      CockpitTaskGate.targetReachable: targetReachable,
      CockpitTaskGate.baselineCollected:
          !request.baseline.captureScreenshot || baselineCollected,
      CockpitTaskGate.executionFinished: executionFinished,
      CockpitTaskGate.bundleWritten: bundleWritten,
      CockpitTaskGate.intendedPlaneWorked: intendedPlaneWorked,
      CockpitTaskGate.fallbackAcceptable: fallbackAcceptable,
      CockpitTaskGate.postconditionsSatisfied: postconditionsSatisfied,
      CockpitTaskGate.artifactsReady: artifactsReady,
      CockpitTaskGate.logsCollected: logsCollected,
      CockpitTaskGate.deliveryReadable: deliveryReadable,
      CockpitTaskGate.deliveryValidated: deliveryValidated,
      CockpitTaskGate.acceptanceEvidenceReadable: acceptanceEvidenceReadable,
      CockpitTaskGate.screenshotReady:
          screenshotReady ?? !request.requirements.requireScreenshotEvidence,
      CockpitTaskGate.recordingReadyOrExplained:
          recordingReadyOrExplained ??
          !request.requirements.requireVideoEvidence,
      CockpitTaskGate.finalAssertionPassed: finalAssertionPassed,
    };
  }

  bool _baselineCollected(
    CockpitRunTaskRequest request,
    CockpitReadTaskBundleSummaryResult bundleSummary,
  ) {
    if (!request.baseline.captureScreenshot) {
      return true;
    }
    return bundleSummary.baselineEvidence != null ||
        bundleSummary.manifest.screenshotCount > 0 ||
        (bundleSummary.artifactPaths.primaryScreenshotPath?.isNotEmpty ??
            false);
  }

  CockpitRunTaskClassification _classify(Map<CockpitTaskGate, bool> gates) {
    if (!(gates[CockpitTaskGate.sessionReachable] ?? false) ||
        !(gates[CockpitTaskGate.targetReachable] ?? false) ||
        !(gates[CockpitTaskGate.executionFinished] ?? false) ||
        !(gates[CockpitTaskGate.bundleWritten] ?? false)) {
      return CockpitRunTaskClassification.blockedByEnvironment;
    }
    if (!(gates[CockpitTaskGate.finalAssertionPassed] ?? false) ||
        !(gates[CockpitTaskGate.postconditionsSatisfied] ?? false)) {
      return CockpitRunTaskClassification.failedWithEvidence;
    }
    if (!(gates[CockpitTaskGate.deliveryValidated] ?? false) ||
        !(gates[CockpitTaskGate.artifactsReady] ?? false) ||
        !(gates[CockpitTaskGate.fallbackAcceptable] ?? false) ||
        !(gates[CockpitTaskGate.deliveryReadable] ?? false)) {
      return CockpitRunTaskClassification.needsMoreWork;
    }
    return CockpitRunTaskClassification.completed;
  }

  CockpitControlScript _withBaseline(
    CockpitControlScript script,
    CockpitRunTaskBaselineRequest baseline,
  ) {
    if (!baseline.captureScreenshot) {
      return script;
    }

    final commands = <CockpitCommand>[
      CockpitCommand(
        commandId: 'baseline_capture',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.baseline,
          name: baseline.screenshotName,
          includeSnapshot: baseline.includeSnapshot,
          attachToStep: true,
          snapshotOptions: const CockpitSnapshotOptions.baseline(),
        ),
      ),
      ...script.commands,
    ];
    final workflowSteps = <CockpitWorkflowStep>[
      CockpitCommandWorkflowStep(
        stepId: 'baseline_capture',
        command: CockpitCommand(
          commandId: 'baseline_capture',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.baseline,
            name: baseline.screenshotName,
            includeSnapshot: baseline.includeSnapshot,
            attachToStep: true,
            snapshotOptions: const CockpitSnapshotOptions.baseline(),
          ),
        ),
      ),
      ...script.workflowSteps,
    ];

    return CockpitControlScript(
      sessionId: script.sessionId,
      taskId: script.taskId,
      platform: script.platform,
      environment: script.environment,
      recording: script.recording,
      commands: commands,
      workflowSteps: script.workflowSteps.isEmpty
          ? const <CockpitWorkflowStep>[]
          : workflowSteps,
      failFast: script.failFast,
    );
  }

  Future<CockpitReadTaskBundleSummaryResult> _readBundleSummary(
    String bundleDir,
  ) async {
    try {
      return await _readSummary(
        CockpitReadTaskBundleSummaryRequest(bundleDir: bundleDir),
      );
    } on CockpitApplicationServiceException {
      rethrow;
    } on Object catch (error) {
      throw CockpitApplicationServiceException(
        code: 'bundleReadFailed',
        message: 'Failed to read the task bundle summary.',
        details: <String, Object?>{
          'bundleDir': bundleDir,
          'error': error.toString(),
        },
      );
    }
  }

  Future<String?> _stopLaunchedApp(
    CockpitRemoteSessionHandle? sessionHandle,
  ) async {
    if (sessionHandle == null) {
      return null;
    }
    try {
      await _stopAutomationApp(
        CockpitAppHandle.fromRemoteSession(sessionHandle),
      );
      return null;
    } on Object catch (error) {
      return 'Automation cleanup failed after task orchestration: $error';
    }
  }

  String _recommendedNextStep(
    CockpitRunTaskClassification classification, {
    required Map<CockpitTaskGate, bool> gates,
  }) {
    switch (classification) {
      case CockpitRunTaskClassification.completed:
        return (gates[CockpitTaskGate.intendedPlaneWorked] ?? true)
            ? 'delivery_ready'
            : 'review_fallbacks';
      case CockpitRunTaskClassification.failedWithEvidence:
        return 'inspect_bundle';
      case CockpitRunTaskClassification.blockedByEnvironment:
        return 'needs_relaunch';
      case CockpitRunTaskClassification.needsMoreWork:
        return 'collect_missing_evidence';
    }
  }

  bool _gateValueOrDefault(
    CockpitBundleGateSummary summary,
    CockpitTaskGate gate,
    bool fallback,
  ) {
    return summary.hasGate(gate) ? summary.isSatisfied(gate) : fallback;
  }
}
