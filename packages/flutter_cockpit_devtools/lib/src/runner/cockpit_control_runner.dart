import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_automation_adapter.dart';
import '../adapters/cockpit_capture_adapter.dart';
import '../adapters/cockpit_recording_adapter.dart';
import '../application/cockpit_command_evidence_defaults.dart';
import 'cockpit_control_run_result.dart';

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
    required List<CockpitCommand> commands,
    CockpitRecordingRequest? recording,
  }) async {
    final capabilities = await _automationAdapter.describeCapabilities();
    final capabilitiesUsed = _capabilitiesUsed(capabilities);
    final artifactPayloads = <String, List<int>>{};
    final artifactSourcePaths = <String, String>{};
    String? failureSummary;
    CockpitRecordingSession? recordingSession;

    if (recording != null) {
      recordingSession = await _startRecording(recording);
    }

    try {
      for (final rawCommand in commands) {
        final command = cockpitCommandWithAiEvidenceDefaults(rawCommand);
        final execution = await _execute(command);
        _sessionController.importStepRecords(execution.runtimeSteps);
        _sessionController.recordCommandResult(command, execution.result);
        artifactPayloads.addAll(execution.artifactPayloads);
        artifactSourcePaths.addAll(execution.artifactSourcePaths);

        if (failFast && !execution.result.success) {
          failureSummary =
              execution.result.error?.message ??
              'Command ${command.commandId} failed.';
          break;
        }
      }
    } finally {
      if (recordingSession != null) {
        final settleDelay = _effectiveRecordingStopSettleDelay(
          recordingSession.request,
        );
        if (settleDelay > Duration.zero) {
          await Future<void>.delayed(settleDelay);
        }
      }
      await _stopRecording(
        session: recordingSession,
        artifactPayloads: artifactPayloads,
        artifactSourcePaths: artifactSourcePaths,
      );
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
    CockpitRecordingRequest request,
  ) async {
    final recordingAdapter = _recordingAdapter;
    if (recordingAdapter == null) {
      throw StateError(
        'Recording was requested but no recording adapter was configured.',
      );
    }

    _sessionController.recordStep(
      actionType: 'recording_start_requested',
      actionArgs: <String, Object?>{
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
          'recordingName': request.name,
          'recordingPurpose': request.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': error.toString(),
        },
      );
      return null;
    }
  }

  Future<void> _stopRecording({
    required CockpitRecordingSession? session,
    required Map<String, List<int>> artifactPayloads,
    required Map<String, String> artifactSourcePaths,
  }) async {
    final recordingAdapter = _recordingAdapter;
    if (session == null || recordingAdapter == null) {
      return;
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
            ? 'recordingStopped'
            : 'recording_failed',
        actionArgs: <String, Object?>{
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': result.state.name,
          if (result.durationMs != null)
            'recordingDurationMs': result.durationMs,
          if (result.failureReason != null)
            'failureReason': result.failureReason,
        },
        artifactRefs: artifact == null
            ? const <CockpitArtifactRef>[]
            : <CockpitArtifactRef>[artifact],
      );
    } catch (error) {
      _sessionController.recordStep(
        actionType: 'recording_failed',
        actionArgs: <String, Object?>{
          'recordingName': session.request.name,
          'recordingPurpose': session.request.purpose.name,
          'recordingState': CockpitRecordingState.failed.name,
          'failureReason': error.toString(),
        },
      );
    }
  }

  Future<CockpitCommandExecution> _execute(CockpitCommand command) {
    if (command.commandType == CockpitCommandType.captureScreenshot &&
        _captureAdapter != null) {
      return _captureAdapter.capture(command);
    }

    return _automationAdapter.execute(command);
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
}
