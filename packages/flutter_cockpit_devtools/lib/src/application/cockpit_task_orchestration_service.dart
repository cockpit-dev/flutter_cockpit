import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cli/cockpit_control_script.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_application_service_exception.dart';
import 'cockpit_launch_remote_session_service.dart';
import 'cockpit_query_remote_session_service.dart';
import 'cockpit_read_task_bundle_summary_service.dart';
import 'cockpit_run_remote_control_script_service.dart';
import 'cockpit_run_task_service.dart';
import 'cockpit_task_gate.dart';
import 'cockpit_task_orchestration_result.dart';
import 'cockpit_task_stage.dart';

typedef CockpitTaskOrchestrationFunction
    = Future<CockpitTaskOrchestrationResult> Function(
  CockpitRunTaskRequest request,
);

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
  })  : _launch = launch ??
            (launchService ?? CockpitLaunchRemoteSessionService()).launch,
        _query =
            query ?? (queryService ?? CockpitQueryRemoteSessionService()).query,
        _runScript = runScript ??
            (runScriptService ?? CockpitRunRemoteControlScriptService()).run,
        _readSummary = readSummary ??
            (readSummaryService ?? const CockpitReadTaskBundleSummaryService())
                .read;

  final CockpitLaunchTaskFunction _launch;
  final CockpitQueryTaskFunction _query;
  final CockpitRunTaskScriptFunction _runScript;
  final CockpitReadTaskSummaryFunction _readSummary;

  Future<CockpitTaskOrchestrationResult> orchestrate(
    CockpitRunTaskRequest request,
  ) async {
    final completedStages = <CockpitTaskStage>{CockpitTaskStage.assess};
    var sessionHandle = request.sessionHandle;
    CockpitRemoteSessionStatus? preflightStatus;

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
      return _blockedResult(
        request: request,
        completedStages: completedStages,
        blockedReason: error.message,
        sessionHandle: sessionHandle,
        preflightStatus: preflightStatus,
      );
    } on Object catch (error) {
      return _blockedResult(
        request: request,
        completedStages: completedStages,
        blockedReason: error.toString(),
        sessionHandle: sessionHandle,
        preflightStatus: preflightStatus,
      );
    }

    completedStages.add(CockpitTaskStage.baseline);
    final script = _withBaseline(request.script, request.baseline);

    completedStages.add(CockpitTaskStage.execute);
    final CockpitRunRemoteControlScriptResult runResult;
    try {
      runResult = await _runScript(
        CockpitRunRemoteControlScriptRequest(
          sessionHandle: sessionHandle,
          sessionHandlePath:
              sessionHandle == null ? request.sessionHandlePath : null,
          script: script,
          outputRoot: request.outputRoot,
          persistScriptPath: request.persistScriptPath,
        ),
      );
    } on CockpitApplicationServiceException catch (error) {
      return _blockedResult(
        request: request,
        completedStages: completedStages,
        blockedReason: error.message,
        sessionHandle: sessionHandle,
        preflightStatus: preflightStatus,
      );
    } on Object catch (error) {
      return _blockedResult(
        request: request,
        completedStages: completedStages,
        blockedReason: error.toString(),
        sessionHandle: sessionHandle,
        preflightStatus: preflightStatus,
      );
    }

    completedStages.add(CockpitTaskStage.observe);
    final CockpitReadTaskBundleSummaryResult bundleSummary;
    try {
      bundleSummary = await _readBundleSummary(runResult.bundleDir.path);
    } on CockpitApplicationServiceException catch (error) {
      return _blockedResult(
        request: request,
        completedStages: completedStages,
        blockedReason: error.message,
        sessionHandle: runResult.sessionHandle ?? sessionHandle,
        preflightStatus: preflightStatus,
      );
    } on Object catch (error) {
      return _blockedResult(
        request: request,
        completedStages: completedStages,
        blockedReason: error.toString(),
        sessionHandle: runResult.sessionHandle ?? sessionHandle,
        preflightStatus: preflightStatus,
      );
    }

    completedStages
      ..add(CockpitTaskStage.judge)
      ..add(CockpitTaskStage.deliver);
    final gates = _buildGates(
      request: request,
      bundleSummary: bundleSummary,
      sessionHandle: runResult.sessionHandle ?? sessionHandle,
    );
    final classification = _classify(gates);

    return CockpitTaskOrchestrationResult(
      classification: classification,
      recommendedNextStep: _recommendedNextStep(classification),
      completedStages: completedStages,
      gates: gates,
      sessionHandle: runResult.sessionHandle ?? sessionHandle,
      preflightStatus: preflightStatus,
      bundleSummary: bundleSummary,
    );
  }

  CockpitTaskOrchestrationResult _blockedResult({
    required CockpitRunTaskRequest request,
    required Set<CockpitTaskStage> completedStages,
    required String blockedReason,
    required CockpitRemoteSessionHandle? sessionHandle,
    required CockpitRemoteSessionStatus? preflightStatus,
  }) {
    return CockpitTaskOrchestrationResult(
      classification: CockpitRunTaskClassification.blockedByEnvironment,
      recommendedNextStep: 'needs_relaunch',
      completedStages: completedStages,
      gates: _defaultGates(
        request,
        sessionReachable: false,
      ),
      sessionHandle: sessionHandle,
      preflightStatus: preflightStatus,
      blockedReason: blockedReason,
    );
  }

  Map<CockpitTaskGate, bool> _buildGates({
    required CockpitRunTaskRequest request,
    required CockpitReadTaskBundleSummaryResult bundleSummary,
    required CockpitRemoteSessionHandle? sessionHandle,
  }) {
    final screenshotReady = !request.requirements.requireScreenshotEvidence ||
        ((bundleSummary.artifactPaths.primaryScreenshotPath?.isNotEmpty ??
                false) ||
            bundleSummary.manifest.deliveryArtifactsReady);
    final recordingReadyOrExplained =
        !request.requirements.requireVideoEvidence ||
            ((bundleSummary.artifactPaths.primaryRecordingPath?.isNotEmpty ??
                    false) ||
                bundleSummary.manifest.deliveryVideoReady);
    final deliveryValidated = screenshotReady &&
        recordingReadyOrExplained &&
        (!request.requirements.requireScreenshotEvidence ||
            bundleSummary.manifest.deliveryArtifactsReady);
    final acceptanceEvidenceReadable = bundleSummary.baselineEvidence != null &&
        bundleSummary.acceptanceEvidence != null &&
        bundleSummary.acceptanceDelta != null &&
        bundleSummary.baselineEvidence!.hasComparableSignals &&
        bundleSummary.acceptanceEvidence!.hasComparableSignals;

    return _defaultGates(
      request,
      sessionReachable: sessionHandle != null,
      baselineCollected: _baselineCollected(request, bundleSummary),
      executionFinished: true,
      bundleWritten: true,
      deliveryValidated: deliveryValidated,
      acceptanceEvidenceReadable: acceptanceEvidenceReadable,
      screenshotReady: screenshotReady,
      recordingReadyOrExplained: recordingReadyOrExplained,
      finalAssertionPassed:
          bundleSummary.manifest.status != CockpitTaskStatus.failed &&
              bundleSummary.manifest.runtimeErrorCount == 0,
    );
  }

  Map<CockpitTaskGate, bool> _defaultGates(
    CockpitRunTaskRequest request, {
    bool sessionReachable = false,
    bool baselineCollected = false,
    bool executionFinished = false,
    bool bundleWritten = false,
    bool deliveryValidated = false,
    bool acceptanceEvidenceReadable = false,
    bool? screenshotReady,
    bool? recordingReadyOrExplained,
    bool finalAssertionPassed = false,
  }) {
    return <CockpitTaskGate, bool>{
      CockpitTaskGate.sessionReachable: sessionReachable,
      CockpitTaskGate.baselineCollected:
          !request.baseline.captureScreenshot || baselineCollected,
      CockpitTaskGate.executionFinished: executionFinished,
      CockpitTaskGate.bundleWritten: bundleWritten,
      CockpitTaskGate.deliveryValidated: deliveryValidated,
      CockpitTaskGate.acceptanceEvidenceReadable: acceptanceEvidenceReadable,
      CockpitTaskGate.screenshotReady:
          screenshotReady ?? !request.requirements.requireScreenshotEvidence,
      CockpitTaskGate.recordingReadyOrExplained: recordingReadyOrExplained ??
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
        !(gates[CockpitTaskGate.executionFinished] ?? false) ||
        !(gates[CockpitTaskGate.bundleWritten] ?? false)) {
      return CockpitRunTaskClassification.blockedByEnvironment;
    }
    if (!(gates[CockpitTaskGate.finalAssertionPassed] ?? false)) {
      return CockpitRunTaskClassification.failedWithEvidence;
    }
    if (!(gates[CockpitTaskGate.deliveryValidated] ?? false)) {
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

    return CockpitControlScript(
      sessionId: script.sessionId,
      taskId: script.taskId,
      platform: script.platform,
      environment: script.environment,
      recording: script.recording,
      commands: commands,
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

  String _recommendedNextStep(CockpitRunTaskClassification classification) {
    switch (classification) {
      case CockpitRunTaskClassification.completed:
        return 'delivery_ready';
      case CockpitRunTaskClassification.failedWithEvidence:
        return 'inspect_bundle';
      case CockpitRunTaskClassification.blockedByEnvironment:
        return 'needs_relaunch';
      case CockpitRunTaskClassification.needsMoreWork:
        return 'collect_missing_evidence';
    }
  }
}
