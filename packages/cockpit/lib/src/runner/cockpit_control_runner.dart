import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_automation_adapter.dart';
import '../adapters/cockpit_capture_adapter.dart';
import '../adapters/cockpit_recording_adapter.dart';
import '../application/cockpit_command_evidence_defaults.dart';
import '../devtools/cockpit_live_run_observer.dart';
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
    CockpitLiveRunObserver? liveObserver,
  }) : _automationAdapter = automationAdapter,
       _captureAdapter = captureAdapter,
       _recordingAdapter = recordingAdapter,
       _sessionController = sessionController,
       _liveObserver = liveObserver;

  final CockpitAutomationAdapter _automationAdapter;
  final CockpitCaptureAdapter? _captureAdapter;
  final CockpitRecordingAdapter? _recordingAdapter;
  final CockpitSessionController _sessionController;
  final CockpitLiveRunObserver? _liveObserver;
  final bool failFast;
  final Duration recordingStopSettleDelay;

  Future<CockpitControlRunResult> run({
    required CockpitEnvironment environment,
    List<CockpitCommand> commands = const <CockpitCommand>[],
    List<CockpitWorkflowStep> workflowSteps = const <CockpitWorkflowStep>[],
    CockpitRecordingRequest? recording,
  }) async {
    try {
      final capabilities = await _automationAdapter.describeCapabilities();
      final capabilitiesUsed = _capabilitiesUsed(capabilities);
      _emitLiveEvent(
        CockpitLiveRunEventDraft(
          type: 'run_started',
          status: 'running',
          stage: 'setup',
          details: <String, Object?>{'capabilitiesUsed': capabilitiesUsed},
        ),
      );
      final artifactPayloads = <String, List<int>>{};
      final artifactSourcePaths = <String, String>{};
      String? failureSummary;
      final recordingState = _WorkflowRecordingState();

      if (recording != null) {
        final startOutcome = await _startRecording(recording);
        recordingState.session = startOutcome.session;
        if (recordingState.session == null) {
          failureSummary = startOutcome.failureSummary;
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
              context: const _WorkflowStepContext.root(),
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

      final CockpitControlRunResult result;
      if (failureSummary != null) {
        result = CockpitControlRunResult(
          bundle: _sessionController.finishWithFailure(
            environment: environment,
            failureSummary: failureSummary,
            capabilitiesUsed: capabilitiesUsed,
          ),
          artifactPayloads: artifactPayloads,
          artifactSourcePaths: artifactSourcePaths,
        );
        _emitLiveEvent(
          CockpitLiveRunEventDraft(
            type: 'run_finished',
            status: 'failed',
            stage: 'finish',
            error: <String, Object?>{'message': failureSummary},
            details: <String, Object?>{'capabilitiesUsed': capabilitiesUsed},
          ),
        );
      } else {
        result = CockpitControlRunResult(
          bundle: _sessionController.finish(
            environment: environment,
            capabilitiesUsed: capabilitiesUsed,
          ),
          artifactPayloads: artifactPayloads,
          artifactSourcePaths: artifactSourcePaths,
        );
        _emitLiveEvent(
          CockpitLiveRunEventDraft(
            type: 'run_finished',
            status: 'completed',
            stage: 'finish',
            details: <String, Object?>{'capabilitiesUsed': capabilitiesUsed},
          ),
        );
      }
      await _flushLiveObserver();
      return result;
    } catch (error) {
      _emitLiveEvent(
        CockpitLiveRunEventDraft(
          type: 'run_finished',
          status: 'failed',
          stage: 'finish',
          error: <String, Object?>{
            'type': error.runtimeType.toString(),
            'message': error.toString(),
          },
        ),
      );
      await _flushLiveObserver();
      rethrow;
    }
  }

  Future<_RecordingStartOutcome> _startRecording(
    CockpitRecordingRequest request, {
    String? workflowStepId,
    String? workflowStepType,
    String? workflowStepDescription,
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
          workflowStepDescription: workflowStepDescription,
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
            workflowStepDescription: workflowStepDescription,
          ),
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': session.state.name,
        },
      );
      return _RecordingStartOutcome.success(session);
    } catch (error) {
      final failureSummary =
          'Recording ${request.name} failed to start: $error';
      _sessionController.recordStep(
        actionType: 'recording_failed',
        actionArgs: <String, Object?>{
          ..._workflowStepRecordingArgs(
            workflowStepId: workflowStepId,
            workflowStepType: workflowStepType,
            workflowStepDescription: workflowStepDescription,
          ),
          'recordingName': request.name,
          'recordingPurpose': request.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': failureSummary,
        },
      );
      return _RecordingStartOutcome.failure(failureSummary);
    }
  }

  Future<_RecordingStopOutcome> _stopRecording({
    required CockpitRecordingSession? session,
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    String? workflowStepId,
    String? workflowStepType,
    String? workflowStepDescription,
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
            workflowStepDescription: workflowStepDescription,
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
        return _RecordingStopOutcome.success(
          artifactRefs: artifact == null
              ? const <CockpitArtifactRef>[]
              : <CockpitArtifactRef>[artifact],
        );
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
            workflowStepDescription: workflowStepDescription,
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
    required _WorkflowStepContext context,
  }) async {
    _emitLiveEvent(
      _liveEventForWorkflowStep(
        step,
        type: 'workflow_step_started',
        status: 'running',
        mode: mode,
        context: context,
      ),
    );
    try {
      final outcome = await switch (step) {
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
          context: context,
        ),
        CockpitLoopWorkflowStep() => _runLoopWorkflowStep(
          step,
          artifactPayloads: artifactPayloads,
          artifactSourcePaths: artifactSourcePaths,
          recordingState: recordingState,
          mode: mode,
          context: context,
        ),
        CockpitRetryWorkflowStep() => _runRetryWorkflowStep(
          step,
          artifactPayloads: artifactPayloads,
          artifactSourcePaths: artifactSourcePaths,
          recordingState: recordingState,
          mode: mode,
          context: context,
        ),
      };
      _emitLiveEvent(
        _liveEventForWorkflowStep(
          step,
          type: 'workflow_step_completed',
          status: outcome.success ? 'completed' : 'failed',
          mode: mode,
          context: context,
          outcome: outcome,
        ),
      );
      return outcome;
    } catch (error) {
      _emitLiveEvent(
        _liveEventForWorkflowStep(
          step,
          type: 'workflow_step_completed',
          status: 'failed',
          mode: mode,
          context: context,
          error: error,
        ),
      );
      rethrow;
    }
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
          if (step.description != null)
            'workflowStepDescription': step.description,
          'recordingName': step.recording.name,
          'recordingPurpose': step.recording.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': failureSummary,
        },
      );
      return _WorkflowStepOutcome.failure(failureSummary);
    }

    try {
      final startOutcome = await _startRecording(
        step.recording,
        workflowStepId: step.stepId,
        workflowStepType: step.stepType,
        workflowStepDescription: step.description,
      );
      recordingState.session = startOutcome.session;
      if (!startOutcome.success) {
        return _WorkflowStepOutcome.failure(startOutcome.failureSummary!);
      }
    } catch (error) {
      final failureSummary = error.toString();
      _sessionController.recordStep(
        actionType: 'recording_failed',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          if (step.description != null)
            'workflowStepDescription': step.description,
          'recordingName': step.recording.name,
          'recordingPurpose': step.recording.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': failureSummary,
        },
      );
      return _WorkflowStepOutcome.failure(failureSummary);
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
          if (step.description != null)
            'workflowStepDescription': step.description,
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
      workflowStepDescription: step.description,
    );
    if (!stopOutcome.success) {
      return _WorkflowStepOutcome.failure(stopOutcome.failureSummary!);
    }
    return _WorkflowStepOutcome.success(artifactRefs: stopOutcome.artifactRefs);
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
          if (step.description != null)
            'workflowStepDescription': step.description,
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
    required _WorkflowStepContext context,
  }) async {
    final condition = await _runProbeCommand(
      step.condition,
      artifactPayloads: artifactPayloads,
      artifactSourcePaths: artifactSourcePaths,
    );
    final controlDetails = <String, Object?>{
      'conditionCommandId': condition.result.commandId,
      'conditionCommandType': condition.result.commandType.name,
      'conditionSuccess': condition.result.success,
      'selectedBranch': condition.result.success ? 'then' : 'else',
      if (condition.result.error != null)
        'conditionError': condition.result.error!.toJson(),
    };
    final selectedSteps = condition.result.success
        ? step.thenSteps
        : step.elseSteps;
    _sessionController.recordStep(
      actionType: 'workflow_if',
      actionArgs: <String, Object?>{
        'workflowStepId': step.stepId,
        'workflowStepType': step.stepType,
        if (step.description != null)
          'workflowStepDescription': step.description,
        ...controlDetails,
      },
      artifactRefs: condition.result.artifacts,
      durationMs: condition.result.durationMs,
    );

    for (var index = 0; index < selectedSteps.length; index += 1) {
      final child = selectedSteps[index];
      final outcome = await _runWorkflowStep(
        child,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
        mode: mode,
        context: context.child(
          parent: step,
          relation: condition.result.success ? 'then' : 'else',
          siblingIndex: index,
        ),
      );
      if (!outcome.success) {
        return outcome.withDetails(controlDetails);
      }
    }
    return _WorkflowStepOutcome.success(details: controlDetails);
  }

  Future<_WorkflowStepOutcome> _runLoopWorkflowStep(
    CockpitLoopWorkflowStep step, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    required _WorkflowRecordingState recordingState,
    required _WorkflowExecutionMode mode,
    required _WorkflowStepContext context,
  }) async {
    for (var index = 0; index < step.maxIterations; index += 1) {
      final condition = await _runProbeCommand(
        step.condition,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
      );
      final conditionSuccess = condition.result.success;
      final controlDetails = <String, Object?>{
        'iteration': index + 1,
        'maxIterations': step.maxIterations,
        'conditionCommandId': condition.result.commandId,
        'conditionCommandType': condition.result.commandType.name,
        'conditionSuccess': conditionSuccess,
        if (condition.result.error != null)
          'conditionError': condition.result.error!.toJson(),
      };
      _sessionController.recordStep(
        actionType: 'workflow_loop_iteration',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          if (step.description != null)
            'workflowStepDescription': step.description,
          ...controlDetails,
        },
        artifactRefs: condition.result.artifacts,
        durationMs: condition.result.durationMs,
      );
      if (!conditionSuccess) {
        return _WorkflowStepOutcome.success(details: controlDetails);
      }

      for (
        var childIndex = 0;
        childIndex < step.steps.length;
        childIndex += 1
      ) {
        final child = step.steps[childIndex];
        final outcome = await _runWorkflowStep(
          child,
          artifactPayloads: artifactPayloads,
          artifactSourcePaths: artifactSourcePaths,
          recordingState: recordingState,
          mode: mode,
          context: context.child(
            parent: step,
            relation: 'loop',
            siblingIndex: childIndex,
            iteration: index + 1,
            maxIterations: step.maxIterations,
          ),
        );
        if (!outcome.success) {
          return outcome.withDetails(controlDetails);
        }
      }
    }
    _sessionController.recordStep(
      actionType: 'workflow_loop_exhausted',
      actionArgs: <String, Object?>{
        'workflowStepId': step.stepId,
        'workflowStepType': step.stepType,
        if (step.description != null)
          'workflowStepDescription': step.description,
        'maxIterations': step.maxIterations,
      },
    );
    return _WorkflowStepOutcome.success(
      details: <String, Object?>{
        'maxIterations': step.maxIterations,
        'loopExhausted': true,
      },
    );
  }

  Future<_WorkflowStepOutcome> _runRetryWorkflowStep(
    CockpitRetryWorkflowStep step, {
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
    required _WorkflowRecordingState recordingState,
    required _WorkflowExecutionMode mode,
    required _WorkflowStepContext context,
  }) async {
    _WorkflowStepOutcome? lastOutcome;
    for (var index = 0; index < step.maxAttempts; index += 1) {
      final outcome = await _runWorkflowStep(
        step.step,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
        recordingState: recordingState,
        mode: _WorkflowExecutionMode.probe,
        context: context.child(
          parent: step,
          relation: 'retry',
          siblingIndex: 0,
          attempt: index + 1,
          maxAttempts: step.maxAttempts,
        ),
      );
      lastOutcome = outcome;
      _sessionController.recordStep(
        actionType: 'workflow_retry_attempt',
        actionArgs: <String, Object?>{
          'workflowStepId': step.stepId,
          'workflowStepType': step.stepType,
          if (step.description != null)
            'workflowStepDescription': step.description,
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
          if (step.description != null)
            'workflowStepDescription': step.description,
        },
      ),
      execution.result,
    );
  }

  CockpitLiveRunEventDraft _liveEventForWorkflowStep(
    CockpitWorkflowStep step, {
    required String type,
    required String status,
    required _WorkflowExecutionMode mode,
    required _WorkflowStepContext context,
    _WorkflowStepOutcome? outcome,
    Object? error,
  }) {
    final command = _commandForWorkflowStep(step);
    final result = outcome?.execution?.result;
    return CockpitLiveRunEventDraft(
      type: type,
      status: status,
      stage: 'control',
      workflowStepId: step.stepId,
      workflowStepType: step.stepType,
      description: step.description,
      commandId: command?.commandId,
      commandType: command?.commandType.name,
      artifactRefs: outcome == null
          ? const <Map<String, Object?>>[]
          : outcome.artifactRefs
                .map((artifact) => artifact.toJson())
                .toList(growable: false),
      error: error == null && outcome?.failureSummary == null
          ? null
          : <String, Object?>{
              if (outcome?.failureSummary != null)
                'message': outcome!.failureSummary,
              if (error != null) ...<String, Object?>{
                'type': error.runtimeType.toString(),
                'message': error.toString(),
              },
            },
      details: <String, Object?>{
        'mode': mode.name,
        ...context.toJson(),
        if (command?.locator != null) 'locator': command!.locator!.toJson(),
        if (command != null && command.parameters.isNotEmpty)
          'parameters': command.parameters,
        if (step is CockpitStartRecordingWorkflowStep)
          'recording': <String, Object?>{
            'purpose': step.recording.purpose.name,
            'name': step.recording.name,
            'mode': step.recording.mode.name,
            'attachToStep': step.recording.attachToStep,
          },
        if (outcome != null) 'success': outcome.success,
        if (outcome != null) ...outcome.details,
        if (result != null) ...<String, Object?>{
          'commandDurationMs': result.durationMs,
          'usedCaptureFallback': result.usedCaptureFallback,
          if (result.requestedCaptureProfile != null)
            'requestedCaptureProfile': result.requestedCaptureProfile!.name,
          if (result.resolvedCaptureKind != null)
            'resolvedCaptureKind': result.resolvedCaptureKind!.name,
        },
      },
    );
  }

  CockpitCommand? _commandForWorkflowStep(CockpitWorkflowStep step) {
    return switch (step) {
      CockpitCommandWorkflowStep() => step.command,
      CockpitIfWorkflowStep() => step.condition,
      CockpitLoopWorkflowStep() => step.condition,
      CockpitRetryWorkflowStep() => _commandForWorkflowStep(step.step),
      CockpitStartRecordingWorkflowStep() => null,
      CockpitStopRecordingWorkflowStep() => null,
    };
  }

  void _emitLiveEvent(CockpitLiveRunEventDraft event) {
    try {
      _liveObserver?.record(event);
    } catch (_) {
      // Observability must never break the underlying control flow.
    }
  }

  Future<void> _flushLiveObserver() async {
    try {
      await _liveObserver?.flush();
    } catch (_) {
      // Returning the automation result is more important than live telemetry.
    }
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
    required String? workflowStepDescription,
  }) {
    final args = <String, Object?>{};
    if (workflowStepId != null) {
      args['workflowStepId'] = workflowStepId;
    }
    if (workflowStepType != null) {
      args['workflowStepType'] = workflowStepType;
    }
    if (workflowStepDescription != null) {
      args['workflowStepDescription'] = workflowStepDescription;
    }
    return args;
  }
}

enum _WorkflowExecutionMode { finalResult, probe }

final class _WorkflowStepContext {
  const _WorkflowStepContext({
    required this.depth,
    this.parentWorkflowStepId,
    this.parentWorkflowStepType,
    this.rootWorkflowStepId,
    this.relation,
    this.siblingIndex,
    this.attempt,
    this.maxAttempts,
    this.iteration,
    this.maxIterations,
  });

  const _WorkflowStepContext.root()
    : depth = 0,
      parentWorkflowStepId = null,
      parentWorkflowStepType = null,
      rootWorkflowStepId = null,
      relation = null,
      siblingIndex = null,
      attempt = null,
      maxAttempts = null,
      iteration = null,
      maxIterations = null;

  final int depth;
  final String? parentWorkflowStepId;
  final String? parentWorkflowStepType;
  final String? rootWorkflowStepId;
  final String? relation;
  final int? siblingIndex;
  final int? attempt;
  final int? maxAttempts;
  final int? iteration;
  final int? maxIterations;

  _WorkflowStepContext child({
    required CockpitWorkflowStep parent,
    required String relation,
    required int siblingIndex,
    int? attempt,
    int? maxAttempts,
    int? iteration,
    int? maxIterations,
  }) {
    return _WorkflowStepContext(
      depth: depth + 1,
      parentWorkflowStepId: parent.stepId,
      parentWorkflowStepType: parent.stepType,
      rootWorkflowStepId: rootWorkflowStepId ?? parent.stepId,
      relation: relation,
      siblingIndex: siblingIndex,
      attempt: attempt,
      maxAttempts: maxAttempts,
      iteration: iteration,
      maxIterations: maxIterations,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'workflowStepDepth': depth,
    if (parentWorkflowStepId != null)
      'parentWorkflowStepId': parentWorkflowStepId,
    if (parentWorkflowStepType != null)
      'parentWorkflowStepType': parentWorkflowStepType,
    if (rootWorkflowStepId != null) 'rootWorkflowStepId': rootWorkflowStepId,
    if (relation != null) 'relation': relation,
    if (siblingIndex != null) 'siblingIndex': siblingIndex,
    if (attempt != null) 'attempt': attempt,
    if (maxAttempts != null) 'maxAttempts': maxAttempts,
    if (iteration != null) 'iteration': iteration,
    if (maxIterations != null) 'maxIterations': maxIterations,
  };
}

final class _WorkflowRecordingState {
  CockpitRecordingSession? session;
}

final class _RecordingStartOutcome {
  const _RecordingStartOutcome.success(CockpitRecordingSession this.session)
    : success = true,
      failureSummary = null;

  const _RecordingStartOutcome.failure(this.failureSummary)
    : success = false,
      session = null;

  final bool success;
  final CockpitRecordingSession? session;
  final String? failureSummary;
}

final class _RecordingStopOutcome {
  const _RecordingStopOutcome.success({
    this.artifactRefs = const <CockpitArtifactRef>[],
  }) : success = true,
       failureSummary = null;

  const _RecordingStopOutcome.failure(this.failureSummary)
    : success = false,
      artifactRefs = const <CockpitArtifactRef>[];

  final bool success;
  final String? failureSummary;
  final List<CockpitArtifactRef> artifactRefs;
}

final class _WorkflowStepOutcome {
  const _WorkflowStepOutcome({
    required this.success,
    this.failureSummary,
    this.commandStep,
    this.command,
    this.execution,
    this.artifactRefs = const <CockpitArtifactRef>[],
    this.details = const <String, Object?>{},
  });

  const _WorkflowStepOutcome.success({
    this.details = const <String, Object?>{},
    this.artifactRefs = const <CockpitArtifactRef>[],
  }) : success = true,
       failureSummary = null,
       commandStep = null,
       command = null,
       execution = null;

  const _WorkflowStepOutcome.failure(String summary)
    : success = false,
      failureSummary = summary,
      commandStep = null,
      command = null,
      execution = null,
      artifactRefs = const <CockpitArtifactRef>[],
      details = const <String, Object?>{};

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
        artifactRefs: result.artifacts,
      );
    }
    return _WorkflowStepOutcome(
      success: false,
      failureSummary:
          result.error?.message ?? 'Command ${result.commandId} failed.',
      commandStep: step,
      command: command,
      execution: execution,
      artifactRefs: result.artifacts,
    );
  }

  final bool success;
  final String? failureSummary;
  final CockpitCommandWorkflowStep? commandStep;
  final CockpitCommand? command;
  final CockpitCommandExecution? execution;
  final List<CockpitArtifactRef> artifactRefs;
  final Map<String, Object?> details;

  _WorkflowStepOutcome withDetails(Map<String, Object?> extraDetails) {
    return _WorkflowStepOutcome(
      success: success,
      failureSummary: failureSummary,
      commandStep: commandStep,
      command: command,
      execution: execution,
      artifactRefs: artifactRefs,
      details: <String, Object?>{...extraDetails, ...details},
    );
  }
}
