export 'cockpit_application_service_exception.dart';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../control_core/cockpit_control_planner.dart';
import '../control_core/cockpit_execution_plan.dart';
import '../control_core/cockpit_intent.dart';
import '../control_core/cockpit_intent_action.dart';
import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_result_profile.dart';
import 'cockpit_interactive_session_lock.dart';
import 'cockpit_interactive_snapshot_store.dart';
import 'cockpit_read_remote_snapshot_service.dart';
import 'cockpit_session_reference_resolver.dart';

typedef CockpitRemoteCommandExecutor = Future<CockpitCommandExecution> Function(
  Uri baseUri,
  CockpitCommand command,
);

final class CockpitExecuteRemoteCommandRequest {
  const CockpitExecuteRemoteCommandRequest({
    required this.command,
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
    this.resultProfile = const CockpitInteractiveResultProfile.standard(),
    this.snapshotOptions,
    this.compareAgainstSnapshotRef,
    this.defaultCommandTimeout = const Duration(seconds: 30),
  });

  final CockpitCommand command;
  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
  final CockpitInteractiveResultProfile resultProfile;
  final CockpitSnapshotOptions? snapshotOptions;
  final String? compareAgainstSnapshotRef;
  final Duration defaultCommandTimeout;
}

final class CockpitExecuteRemoteCommandResult {
  const CockpitExecuteRemoteCommandResult({
    required this.command,
    required this.artifacts,
    this.selectedPlane = CockpitPlaneKind.flutterSemanticPlane,
    this.fallbackTrail = const <CockpitPlaneKind>[],
    this.recommendedNextStep = 'continue',
    this.whatChanged,
    this.whatMatters,
    this.uiSummary,
    this.snapshot,
    this.diagnostics,
    this.runtimeSteps = const <Map<String, Object?>>[],
    this.delta,
    this.snapshotRef,
    this.sessionHandle,
    this.effectiveSnapshotOptions,
  });

  final CockpitInteractiveCommandCore command;
  final List<CockpitInteractiveArtifactDescriptor> artifacts;
  final CockpitPlaneKind selectedPlane;
  final List<CockpitPlaneKind> fallbackTrail;
  final String recommendedNextStep;
  final String? whatChanged;
  final String? whatMatters;
  final CockpitInteractiveSnapshotSummary? uiSummary;
  final CockpitSnapshot? snapshot;
  final Map<String, Object?>? diagnostics;
  final List<Map<String, Object?>> runtimeSteps;
  final CockpitInteractiveSnapshotDelta? delta;
  final String? snapshotRef;
  final CockpitRemoteSessionHandle? sessionHandle;
  final CockpitSnapshotOptions? effectiveSnapshotOptions;

  Map<String, Object?> toJson() => <String, Object?>{
        'command': command.toJson(),
        'artifacts': artifacts.map((artifact) => artifact.toJson()).toList(),
        'selectedPlane': selectedPlane.name,
        'fallbackTrail':
            fallbackTrail.map((planeKind) => planeKind.name).toList(),
        'recommendedNextStep': recommendedNextStep,
        if (whatChanged != null) 'whatChanged': whatChanged,
        if (whatMatters != null) 'whatMatters': whatMatters,
        if (uiSummary != null) 'uiSummary': uiSummary!.toJson(),
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (diagnostics != null) 'diagnostics': diagnostics,
        'runtimeSteps': runtimeSteps,
        if (delta != null) 'delta': delta!.toJson(),
        if (snapshotRef != null) 'snapshotRef': snapshotRef,
        if (sessionHandle != null) 'sessionHandle': sessionHandle!.toJson(),
        if (effectiveSnapshotOptions != null)
          'effectiveSnapshotOptions': effectiveSnapshotOptions!.toJson(),
      };
}

final class CockpitExecuteRemoteCommandService {
  CockpitExecuteRemoteCommandService({
    CockpitRemoteCommandExecutor? executeCommand,
    CockpitRemoteSnapshotDetailedReader? readSnapshot,
    CockpitSessionReferenceResolver? sessionReferenceResolver,
    CockpitInteractiveSnapshotStore? snapshotStore,
    CockpitInteractiveSessionLock? sessionLock,
  })  : _executeCommand = executeCommand ??
            ((baseUri, command) => CockpitRemoteSessionClient(
                  baseUri: baseUri,
                  requestTimeout: _remoteRequestTimeoutFor(command),
                ).executeDetailed(command)),
        _readSnapshot = readSnapshot ??
            ((baseUri, options) => CockpitRemoteSessionClient(
                  baseUri: baseUri,
                ).readSnapshotDetailed(options: options)),
        _sessionReferenceResolver =
            sessionReferenceResolver ?? CockpitSessionReferenceResolver(),
        _snapshotStore = snapshotStore ?? CockpitInteractiveSnapshotStore(),
        _sessionLock = sessionLock ?? CockpitInteractiveSessionLock();

  final CockpitRemoteCommandExecutor _executeCommand;
  final CockpitRemoteSnapshotDetailedReader _readSnapshot;
  final CockpitSessionReferenceResolver _sessionReferenceResolver;
  final CockpitInteractiveSnapshotStore _snapshotStore;
  final CockpitInteractiveSessionLock _sessionLock;

  Future<CockpitExecuteRemoteCommandResult> execute(
    CockpitExecuteRemoteCommandRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.androidDeviceId,
    );
    final sessionKey = resolved.baseUri.toString();

    return _sessionLock.run(sessionKey, () async {
      final effectiveCommand = _withDefaultTimeout(
        request.command,
        defaultTimeout: request.defaultCommandTimeout,
      );
      final intent = CockpitIntent.fromCommand(effectiveCommand);
      final executionPlan = CockpitControlPlanner().plan(
        intent: intent,
        capabilityProfile: _legacyFlutterCapabilityProfile(intent),
      );
      final execution =
          await _executeCommand(resolved.baseUri, effectiveCommand);
      final effectiveSnapshotOptions =
          request.resultProfile.requiresPostActionSnapshotRead(
        compareAgainstSnapshot: request.compareAgainstSnapshotRef != null,
      )
              ? request.resultProfile.resolveSnapshotOptions(
                  request.snapshotOptions ?? effectiveCommand.snapshotOptions,
                )
              : null;
      final snapshot = effectiveSnapshotOptions == null
          ? null
          : (await cockpitReadRemoteSnapshotConsistently(
              baseUri: resolved.baseUri,
              options: effectiveSnapshotOptions,
              readSnapshot: _readSnapshot,
            ))
              .snapshot;
      final baseline = request.compareAgainstSnapshotRef == null
          ? null
          : _snapshotStore.read(
              request.compareAgainstSnapshotRef!,
              sessionKey: sessionKey,
            );
      final snapshotRef =
          snapshot == null || !request.resultProfile.emitsSnapshotRef
              ? null
              : _snapshotStore.put(sessionKey: sessionKey, snapshot: snapshot);

      return CockpitExecuteRemoteCommandResult(
        command: CockpitInteractiveCommandCore.fromResult(execution.result),
        artifacts: cockpitInteractiveArtifactsFromExecution(
          execution,
          request.resultProfile.artifacts,
        ),
        selectedPlane: executionPlan.selectedPlane,
        fallbackTrail: executionPlan.fallbackChain,
        recommendedNextStep: _recommendedNextStep(
          execution: execution,
          executionPlan: executionPlan,
        ),
        whatChanged: _whatChanged(execution.result),
        whatMatters: _whatMatters(execution.result),
        uiSummary: snapshot == null || !request.resultProfile.emitsUiSummary
            ? null
            : cockpitInteractiveSummarizeSnapshot(snapshot),
        snapshot: request.resultProfile.emitsInlineSnapshot ? snapshot : null,
        diagnostics: snapshot == null
            ? null
            : cockpitInteractiveDiagnosticsFromSnapshot(
                snapshot,
                request.resultProfile.diagnostics,
              ),
        runtimeSteps: request.resultProfile.emitsRuntimeSteps
            ? execution.runtimeSteps
                .map((step) => (step.toJson()))
                .toList(growable: false)
            : const <Map<String, Object?>>[],
        delta: snapshot == null || baseline == null
            ? null
            : cockpitInteractiveDiffSnapshots(baseline.snapshot, snapshot),
        snapshotRef: snapshotRef,
        sessionHandle: resolved.sessionHandle,
        effectiveSnapshotOptions: effectiveSnapshotOptions,
      );
    });
  }

  static CockpitCommand _withDefaultTimeout(
    CockpitCommand command, {
    required Duration defaultTimeout,
  }) {
    if (command.timeoutMs != null && command.timeoutMs! > 0) {
      return command;
    }
    final recommendedTimeout = _recommendedCommandTimeout(
      command,
      defaultTimeout: defaultTimeout,
    );
    return command.copyWith(timeoutMs: recommendedTimeout.inMilliseconds);
  }

  static Duration _remoteRequestTimeoutFor(CockpitCommand command) {
    const requestBuffer = Duration(seconds: 3);
    const minimumTimeout = Duration(seconds: 6);
    final commandTimeout = Duration(
      milliseconds:
          command.timeoutMs ?? const Duration(seconds: 4).inMilliseconds,
    );
    final timeout = commandTimeout + requestBuffer;
    return timeout < minimumTimeout ? minimumTimeout : timeout;
  }

  static Duration _recommendedCommandTimeout(
    CockpitCommand command, {
    required Duration defaultTimeout,
  }) {
    var recommended = defaultTimeout;
    final parameterTimeoutMs = _positiveInt(command.parameters['timeoutMs']);
    switch (command.commandType) {
      case CockpitCommandType.scrollUntilVisible:
        final maxScrolls = _positiveInt(command.parameters['maxScrolls']) ?? 12;
        final durationPerStepMs =
            _positiveInt(command.parameters['durationPerStepMs']) ?? 220;
        final probeSegments = _recommendedScrollProbeSegments(command);
        final revealRequested = command.parameters['revealAlignment'] != null ||
            (_positiveNum(command.parameters['revealPadding']) ?? 0) > 0;
        final perStepBudgetMs =
            probeSegments * (durationPerStepMs + (revealRequested ? 420 : 320));
        final stepBudgetMs = maxScrolls * perStepBudgetMs;
        recommended = _maxDuration(
          recommended,
          Duration(milliseconds: stepBudgetMs + 1800),
        );
      case CockpitCommandType.waitFor ||
            CockpitCommandType.waitForUiIdle ||
            CockpitCommandType.waitForNetworkIdle:
        if (parameterTimeoutMs != null) {
          recommended = _maxDuration(
            recommended,
            Duration(milliseconds: parameterTimeoutMs),
          );
        }
      default:
        if (parameterTimeoutMs != null) {
          recommended = _maxDuration(
            recommended,
            Duration(milliseconds: parameterTimeoutMs),
          );
        }
    }
    return recommended;
  }

  static int? _positiveInt(Object? value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is num) {
      final normalized = value.toInt();
      return normalized > 0 ? normalized : null;
    }
    return null;
  }

  static double? _positiveNum(Object? value) {
    if (value is num && value > 0) {
      return value.toDouble();
    }
    return null;
  }

  static int _recommendedScrollProbeSegments(CockpitCommand command) {
    if (command.locator == null) {
      return 1;
    }
    final viewportFraction =
        (_positiveNum(command.parameters['viewportFraction']) ?? 0.8)
            .clamp(0.1, 0.95)
            .toDouble();
    if (viewportFraction < 0.4) {
      return 1;
    }
    return (viewportFraction / 0.2).floor().clamp(1, 4);
  }

  static Duration _maxDuration(Duration left, Duration right) {
    return left >= right ? left : right;
  }

  static CockpitCapabilityProfile _legacyFlutterCapabilityProfile(
    CockpitIntent intent,
  ) {
    return CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.flutterApp,
      surfaceKinds: <CockpitSurfaceKind>{
        CockpitSurfaceKind.flutterSemantic,
        CockpitSurfaceKind.nativeUi,
      },
      actionCapabilities: <CockpitActionCapability>{
        CockpitActionCapability.tap,
        CockpitActionCapability.typeText,
        CockpitActionCapability.captureScreenshot,
        CockpitActionCapability.readLogs,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        CockpitEvidenceCapability.flutterScreenshot,
        if (intent.action == CockpitIntentAction.captureScreenshot)
          CockpitEvidenceCapability.nativeScreenshot,
      },
    );
  }

  static String _recommendedNextStep({
    required CockpitCommandExecution execution,
    required CockpitExecutionPlan executionPlan,
  }) {
    if (!execution.result.success) {
      return 'inspectFailureDiagnostics';
    }
    if (executionPlan.requiresObservation) {
      return 'readPostActionState';
    }
    if (executionPlan.requiresEvidence) {
      return 'reviewCapturedEvidence';
    }
    return 'continue';
  }

  static String _whatChanged(CockpitCommandResult result) {
    return result.success
        ? 'Command ${result.commandId} completed successfully.'
        : 'Command ${result.commandId} failed.';
  }

  static String? _whatMatters(CockpitCommandResult result) {
    if (result.error != null) {
      return result.error!.message;
    }
    if (result.degradationReason != null &&
        result.degradationReason!.isNotEmpty) {
      return result.degradationReason;
    }
    if (result.usedCaptureFallback) {
      return 'Capture completed with a fallback path.';
    }
    return null;
  }
}
