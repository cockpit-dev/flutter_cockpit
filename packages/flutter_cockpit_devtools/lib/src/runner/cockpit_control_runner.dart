import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_automation_adapter.dart';
import '../adapters/cockpit_capture_adapter.dart';
import '../adapters/cockpit_recording_adapter.dart';
import '../application/cockpit_command_evidence_defaults.dart';
import 'cockpit_control_run_result.dart';
import 'cockpit_workflow_step.dart';

final class CockpitControlRunner {
  CockpitControlRunner({
    required CockpitAutomationAdapter automationAdapter,
    CockpitCaptureAdapter? captureAdapter,
    CockpitRecordingAdapter? recordingAdapter,
    required CockpitSessionController sessionController,
    this.failFast = true,
    this.recordingStopSettleDelay = const Duration(milliseconds: 1400),
  }) : _automationAdapter = automationAdapter,
       _captureAdapter = captureAdapter,
       _recordingAdapter = recordingAdapter,
       _sessionController = sessionController;

  final CockpitAutomationAdapter _automationAdapter;
  final CockpitCaptureAdapter? _captureAdapter;
  final CockpitRecordingAdapter? _recordingAdapter;
  final CockpitSessionController _sessionController;
  final bool failFast;
  final Duration recordingStopSettleDelay;

  Future<CockpitControlRunResult> run({
    required CockpitEnvironment environment,
    List<CockpitCommand> commands = const <CockpitCommand>[],
    List<CockpitWorkflowStep> workflowSteps = const <CockpitWorkflowStep>[],
    CockpitRecordingRequest? recording,
  }) async {
    final capabilities = await _automationAdapter.describeCapabilities();
    final capabilitiesUsed = _capabilitiesUsed(capabilities);
    final artifactPayloads = <String, List<int>>{};
    final artifactSourcePaths = <String, String>{};
    String? failureSummary;
    final recordingState = _WorkflowRecordingState();

    if (recording != null) {
      recordingState.session = await _startRecording(recording);
      if (recordingState.session == null) {
        failureSummary = 'Recording ${recording.name} failed to start.';
      }
    }

    try {
      if (failureSummary == null) {
        final effectiveSteps = workflowSteps.isNotEmpty
            ? workflowSteps
            : cockpitWorkflowStepsFromCommands(commands);
        for (final step in effectiveSteps) {
          final outcome = await _runWorkflowStep(
            step,
            artifactPayloads: artifactPayloads,
            artifactSourcePaths: artifactSourcePaths,
            recordingState: recordingState,
            mode: _WorkflowExecutionMode.finalResult,
          );
          if (!outcome.success) {
            failureSummary = outcome.failureSummary;
            if (failFast) {
              break;
            }
          }
        }
      }
    } finally {
      final recordingSession = recordingState.session;
      recordingState.session = null;
      if (recordingSession != null) {
        final settleDelay = _effectiveRecordingStopSettleDelay(
          recordingSession.request,
        );
        if (settleDelay > Duration.zero) {
          await Future<void>.delayed(settleDelay);
        }
      }
      final stopOutcome = await _stopRecording(
        session: recordingSession,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
      );
      if (!stopOutcome.success && failureSummary == null) {
        failureSummary = stopOutcome.failureSummary;
      }
    }

    if (failureSummary != null) {
      return CockpitControlRunResult(
        bundle: _sessionController.finishWithFailure(
          environment: environment,
          failureSummary: failureSummary,
          capabilitiesUsed: capabilitiesUsed,
        ),
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
      );
    }

    return CockpitControlRunResult(
      bundle: _sessionController.finish(
        environment: environment,
        capabilitiesUsed: capabilitiesUsed,
      ),
      artifactPayloads: artifactPayloads,
      artifactSourcePaths: artifactSourcePaths,
    );
  }

  Future<CockpitRecordingSession?> _startRecording(
    CockpitRecordingRequest request, {
    String? workflowStepId,
    String? workflowStepType,
  }) async {
    final recordingAdapter = _recordingAdapter;
    if (recordingAdapter == null) {
      throw StateError(
        'Recording was requested but no recording adapter was configured.',
      );
    }

    _sessionController.recordStep(
      actionType: 'recording_start_requested',
      actionArgs: <String, Object?>{
        ..._workflowStepRecordingArgs(
          workflowStepId: workflowStepId,
          workflowStepType: workflowStepType,
        ),
        'recordingName': request.name,
        'recordingPurpose': request.purpose.name,
        'recordingState': CockpitRecordingState.starting.name,
      },
    );

    try {
      final session = await recordingAdapter.startRecording(request);
      _sessionController.recordStep(
        actionType: 'recording_started',
        actionArgs: <String, Object?>{
          ..._workflowStepRecordingArgs(
            workflowStepId: workflowStepId,
            workflowStepType: workflowStepType,
          ),
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': session.state.name,
        },
      );
      return session;
    } catch (error) {
      _sessionController.recordStep(
        actionType: 'recording_failed',
        actionArgs: <String, Object?>{
          ..._workflowStepRecordingArgs(
            workflowStepId: workflowStepId,
            workflowStepType: workflowStepType,
          ),
          'recordingName': request.name,
          'recordingPurpose': request.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': error.toString(),
        },
      );
      return null;
    }
  }

  Future<_RecordingStopOutcome> _stopRecording({
    required CockpitRecordingSession? session,
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    String? workflowStepId,
    String? workflowStepType,
  }) async {
    final recordingAdapter = _recordingAdapter;
    if (session == null || recordingAdapter == null) {
      return const _RecordingStopOutcome.success();
    }

    try {
      final result = await recordingAdapter.stopRecording();
      final artifact = result.artifact;
      if (artifact != null) {
        final bytes = result.bytes;
        if (bytes != null) {
          artifactPayloads[artifact.relativePath] = bytes;
        }
        final sourceFilePath = result.sourceFilePath;
        if (sourceFilePath != null && sourceFilePath.isNotEmpty) {
          artifactSourcePaths[artifact.relativePath] = sourceFilePath;
        }
      }
      _sessionController.recordStep(
        actionType: result.state == CockpitRecordingState.completed
            ? 'recording_stopped'
            : 'recording_failed',
        actionArgs: <String, Object?>{
          ..._workflowStepRecordingArgs(
            workflowStepId: workflowStepId,
            workflowStepType: workflowStepType,
          ),
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': result.state.name,
          if (result.recordingKind != null)
            'recordingKind': result.recordingKind!.name,
          if (result.durationMs != null)
            'recordingDurationMs': result.durationMs,
          if (result.failureReason != null)
            'failureReason': result.failureReason,
        },
        artifactRefs: artifact == null
            ? const <CockpitArtifactRef>[]
            : <CockpitArtifactRef>[artifact],
      );
      if (result.state == CockpitRecordingState.completed) {
        return const _RecordingStopOutcome.success();
      }
      return _RecordingStopOutcome.failure(
        result.failureReason ?? 'Recording did not complete successfully.',
      );
    } catch (error) {
      _sessionController.recordStep(
        actionType: 'recording_failed',
        actionArgs: <String, Object?>{
          ..._workflowStepRecordingArgs(
            workflowStepId: workflowStepId,
            workflowStepType: workflowStepType,
          ),
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': error.toString(),
        },
      );
      return _RecordingStopOutcome.failure(error.toString());
    }
  }

  Future<CockpitCommandExecution> _execute(CockpitCommand command) {
    if (command.commandType == CockpitCommandType.captureScreenshot &&
        _captureAdapter != null) {
      return _captureAdapter.capture(command);
    }

    return _automationAdapter.execute(command);
  }

  Future<_WorkflowStepOutcome> _runWorkflowStep(
    CockpitWorkflowStep step, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    required _WorkflowRecordingState recordingState,
    required _WorkflowExecutionMode mode,
  }) async {
    return switch (step) {
      CockpitStartRecordingWorkflowStep() => _runStartRecordingWorkflowStep(
        step,
        recordingState: recordingState,
      ),
      CockpitStopRecordingWorkflowStep() => _runStopRecordingWorkflowStep(
        step,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
      ),
      CockpitCommandWorkflowStep() => _runCommandWorkflowStep(
        step,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
        mode: mode,
      ),
      CockpitIfWorkflowStep() => _runIfWorkflowStep(
        step,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
        mode: mode,
      ),
      CockpitLoopWorkflowStep() => _runLoopWorkflowStep(
        step,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
        mode: mode,
      ),
      CockpitRetryWorkflowStep() => _runRetryWorkflowStep(
        step,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
        mode: mode,
      ),
    };
  }

  Future<_WorkflowStepOutcome> _runStartRecordingWorkflowStep(
    CockpitStartRecordingWorkflowStep step, {
    required _WorkflowRecordingState recordingState,
  }) async {
    if (recordingState.session != null) {
      final failureSummary =
          'A workflow recording is already active; stop it before starting ${step.recording.name}.';
      _sessionController.recordStep(
        actionType: 'recording_failed',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          'recordingName': step.recording.name,
          'recordingPurpose': step.recording.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': failureSummary,
        },
      );
      return _WorkflowStepOutcome.failure(failureSummary);
    }

    try {
      recordingState.session = await _startRecording(
        step.recording,
        workflowStepId: step.stepId,
        workflowStepType: step.stepType,
      );
    } catch (error) {
      final failureSummary = error.toString();
      _sessionController.recordStep(
        actionType: 'recording_failed',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          'recordingName': step.recording.name,
          'recordingPurpose': step.recording.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': failureSummary,
        },
      );
      return _WorkflowStepOutcome.failure(failureSummary);
    }

    if (recordingState.session == null) {
      return _WorkflowStepOutcome.failure(
        'Recording ${step.recording.name} failed to start.',
      );
    }
    return const _WorkflowStepOutcome.success();
  }

  Future<_WorkflowStepOutcome> _runStopRecordingWorkflowStep(
    CockpitStopRecordingWorkflowStep step, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    required _WorkflowRecordingState recordingState,
  }) async {
    final session = recordingState.session;
    if (session == null) {
      const failureSummary =
          'No active workflow recording is available to stop.';
      _sessionController.recordStep(
        actionType: 'recording_failed',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': failureSummary,
        },
      );
      return const _WorkflowStepOutcome.failure(failureSummary);
    }

    recordingState.session = null;
    if (step.settleDelay > Duration.zero) {
      await Future<void>.delayed(step.settleDelay);
    }
    final stopOutcome = await _stopRecording(
      session: session,
      artifactPayloads: artifactPayloads,
      artifactSourcePaths: artifactSourcePaths,
      workflowStepId: step.stepId,
      workflowStepType: step.stepType,
    );
    if (!stopOutcome.success) {
      return _WorkflowStepOutcome.failure(stopOutcome.failureSummary!);
    }
    return const _WorkflowStepOutcome.success();
  }

  Future<_WorkflowStepOutcome> _runCommandWorkflowStep(
    CockpitCommandWorkflowStep step, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    required _WorkflowRecordingState recordingState,
    required _WorkflowExecutionMode mode,
  }) async {
    final command = cockpitCommandWithAiEvidenceDefaults(step.command);
    final execution = await _execute(command);
    artifactPayloads.addAll(execution.artifactPayloads);
    artifactSourcePaths.addAll(execution.artifactSourcePaths);

    if (mode == _WorkflowExecutionMode.finalResult) {
      _recordCommandExecution(step, command, execution);
    } else {
      _sessionController.recordStep(
        actionType: 'workflow_command_attempt',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          'commandId': command.commandId,
          'commandType': command.commandType.name,
          'success': execution.result.success,
          if (execution.result.error != null)
            'commandError': execution.result.error!.toJson(),
        },
        artifactRefs: execution.result.artifacts,
        durationMs: execution.result.durationMs,
      );
    }

    return _WorkflowStepOutcome.fromCommandResult(
      step: step,
      command: command,
      execution: execution,
    );
  }

  Future<_WorkflowStepOutcome> _runIfWorkflowStep(
    CockpitIfWorkflowStep step, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    required _WorkflowRecordingState recordingState,
    required _WorkflowExecutionMode mode,
  }) async {
    final condition = await _runProbeCommand(
      step.condition,
      artifactPayloads: artifactPayloads,
      artifactSourcePaths: artifactSourcePaths,
    );
    final selectedSteps = condition.result.success
        ? step.thenSteps
        : step.elseSteps;
    _sessionController.recordStep(
      actionType: 'workflow_if',
      actionArgs: <String, Object?>{
        'workflowStepId': step.stepId,
        'workflowStepType': step.stepType,
        'conditionCommandId': condition.result.commandId,
        'conditionCommandType': condition.result.commandType.name,
        'conditionSuccess': condition.result.success,
        'selectedBranch': condition.result.success ? 'then' : 'else',
        if (condition.result.error != null)
          'conditionError': condition.result.error!.toJson(),
      },
      artifactRefs: condition.result.artifacts,
      durationMs: condition.result.durationMs,
    );

    for (final child in selectedSteps) {
      final outcome = await _runWorkflowStep(
        child,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
        mode: mode,
      );
      if (!outcome.success) {
        return outcome;
      }
    }
    return const _WorkflowStepOutcome.success();
  }

  Future<_WorkflowStepOutcome> _runLoopWorkflowStep(
    CockpitLoopWorkflowStep step, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    required _WorkflowRecordingState recordingState,
    required _WorkflowExecutionMode mode,
  }) async {
    for (var index = 0; index < step.maxIterations; index += 1) {
      final condition = await _runProbeCommand(
        step.condition,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
      );
      final conditionSuccess = condition.result.success;
      _sessionController.recordStep(
        actionType: 'workflow_loop_iteration',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          'iteration': index + 1,
          'maxIterations': step.maxIterations,
          'conditionCommandId': condition.result.commandId,
          'conditionCommandType': condition.result.commandType.name,
          'conditionSuccess': conditionSuccess,
          if (condition.result.error != null)
            'conditionError': condition.result.error!.toJson(),
        },
        artifactRefs: condition.result.artifacts,
        durationMs: condition.result.durationMs,
      );
      if (!conditionSuccess) {
        return const _WorkflowStepOutcome.success();
      }

      for (final child in step.steps) {
        final outcome = await _runWorkflowStep(
          child,
          artifactPayloads: artifactPayloads,
          artifactSourcePaths: artifactSourcePaths,
          recordingState: recordingState,
          mode: mode,
        );
        if (!outcome.success) {
          return outcome;
        }
      }
    }
    _sessionController.recordStep(
      actionType: 'workflow_loop_exhausted',
      actionArgs: <String, Object?>{
        'workflowStepId': step.stepId,
        'workflowStepType': step.stepType,
        'maxIterations': step.maxIterations,
      },
    );
    return const _WorkflowStepOutcome.success();
  }

  Future<_WorkflowStepOutcome> _runRetryWorkflowStep(
    CockpitRetryWorkflowStep step, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    required _WorkflowRecordingState recordingState,
    required _WorkflowExecutionMode mode,
  }) async {
    _WorkflowStepOutcome? lastOutcome;
    for (var index = 0; index < step.maxAttempts; index += 1) {
      final outcome = await _runWorkflowStep(
        step.step,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
        mode: _WorkflowExecutionMode.probe,
      );
      lastOutcome = outcome;
      _sessionController.recordStep(
        actionType: 'workflow_retry_attempt',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          'attempt': index + 1,
          'maxAttempts': step.maxAttempts,
          'success': outcome.success,
          if (outcome.failureSummary != null)
            'failureSummary': outcome.failureSummary,
        },
      );
      final isFinalAttempt = index + 1 == step.maxAttempts;
      if (outcome.success || isFinalAttempt) {
        if (mode == _WorkflowExecutionMode.finalResult) {
          final commandStep = outcome.commandStep;
          final command = outcome.command;
          final execution = outcome.execution;
          if (commandStep != null && command != null && execution != null) {
            _recordCommandExecution(commandStep, command, execution);
          }
        }
        if (!outcome.success) {
          return outcome;
        }
        return const _WorkflowStepOutcome.success();
      }
      if (step.delayMs > 0) {
        await Future<void>.delayed(Duration(milliseconds: step.delayMs));
      }
    }
    return lastOutcome ?? const _WorkflowStepOutcome.failure('Retry failed.');
  }

  Future<CockpitCommandExecution> _runProbeCommand(
    CockpitCommand rawCommand, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
  }) async {
    final command = cockpitCommandWithAiEvidenceDefaults(rawCommand);
    final execution = await _execute(command);
    artifactPayloads.addAll(execution.artifactPayloads);
    artifactSourcePaths.addAll(execution.artifactSourcePaths);
    return execution;
  }

  void _recordCommandExecution(
    CockpitCommandWorkflowStep step,
    CockpitCommand command,
    CockpitCommandExecution execution,
  ) {
    _sessionController.importStepRecords(execution.runtimeSteps);
    _sessionController.recordCommandResult(
      command.copyWith(
        parameters: <String, Object?>{
          ...command.parameters,
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
        },
      ),
      execution.result,
    );
  }

  List<String> _capabilitiesUsed(CockpitCapabilities capabilities) {
    return <String>[
      if (capabilities.supportsInAppControl) 'inAppControl',
      if (capabilities.supportsFlutterViewCapture) 'flutterViewCapture',
      if (capabilities.supportsNativeScreenCapture) 'nativeScreenCapture',
      if (capabilities.supportsHostAutomation) 'hostAutomation',
    ];
  }

  Duration _effectiveRecordingStopSettleDelay(CockpitRecordingRequest request) {
    return request.tailStabilizationDelay > Duration.zero
        ? request.tailStabilizationDelay
        : recordingStopSettleDelay;
  }

  Map<String, Object?> _workflowStepRecordingArgs({
    required String? workflowStepId,
    required String? workflowStepType,
  }) {
    final args = <String, Object?>{};
    if (workflowStepId != null) {
      args['workflowStepId'] = workflowStepId;
    }
    if (workflowStepType != null) {
      args['workflowStepType'] = workflowStepType;
    }
    return args;
  }
}

enum _WorkflowExecutionMode { finalResult, probe }

final class _WorkflowRecordingState {
  CockpitRecordingSession? session;
}

final class _RecordingStopOutcome {
  const _RecordingStopOutcome.success() : success = true, failureSummary = null;

  const _RecordingStopOutcome.failure(this.failureSummary) : success = false;

  final bool success;
  final String? failureSummary;
}

final class _WorkflowStepOutcome {
  const _WorkflowStepOutcome({
    required this.success,
    this.failureSummary,
    this.commandStep,
    this.command,
    this.execution,
  });

  const _WorkflowStepOutcome.success()
    : success = true,
      failureSummary = null,
      commandStep = null,
      command = null,
      execution = null;

  const _WorkflowStepOutcome.failure(String summary)
    : success = false,
      failureSummary = summary,
      commandStep = null,
      command = null,
      execution = null;

  factory _WorkflowStepOutcome.fromCommandResult({
    required CockpitCommandWorkflowStep step,
    required CockpitCommand command,
    required CockpitCommandExecution execution,
  }) {
    final result = execution.result;
    if (result.success) {
      return _WorkflowStepOutcome(
        success: true,
        commandStep: step,
        command: command,
        execution: execution,
      );
    }
    return _WorkflowStepOutcome(
      success: false,
      failureSummary:
          result.error?.message ?? 'Command ${result.commandId} failed.',
      commandStep: step,
      command: command,
      execution: execution,
    );
  }

  final bool success;
  final String? failureSummary;
  final CockpitCommandWorkflowStep? commandStep;
  final CockpitCommand? command;
  final CockpitCommandExecution? execution;
}
