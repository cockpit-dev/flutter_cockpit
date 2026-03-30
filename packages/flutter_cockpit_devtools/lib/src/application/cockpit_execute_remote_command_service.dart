export 'cockpit_application_service_exception.dart';

import 'package:flutter_cockpit/flutter_cockpit.dart';

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
  });

  final CockpitCommand command;
  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
  final CockpitInteractiveResultProfile resultProfile;
  final CockpitSnapshotOptions? snapshotOptions;
  final String? compareAgainstSnapshotRef;
}

final class CockpitExecuteRemoteCommandResult {
  const CockpitExecuteRemoteCommandResult({
    required this.command,
    required this.artifacts,
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
        'ui_summary': uiSummary?.toJson(),
        'snapshot': snapshot?.toJson(),
        'diagnostics': diagnostics,
        'runtime_steps': runtimeSteps,
        'delta': delta?.toJson(),
        'snapshot_ref': snapshotRef,
        'session_handle': sessionHandle?.toJson(),
        'effective_snapshot_options': effectiveSnapshotOptions?.toJson(),
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
      final execution =
          await _executeCommand(resolved.baseUri, request.command);
      final needsSnapshot =
          request.resultProfile.ui != CockpitInteractiveUiLevel.none ||
              request.resultProfile.diagnostics !=
                  CockpitInteractiveDiagnosticsLevel.none ||
              request.resultProfile.includeDelta ||
              request.resultProfile.emitSnapshotRef ||
              request.compareAgainstSnapshotRef != null;
      final effectiveSnapshotOptions = needsSnapshot
          ? request.resultProfile.resolveSnapshotOptions(
              request.snapshotOptions ?? request.command.snapshotOptions,
            )
          : null;
      final snapshot = effectiveSnapshotOptions == null
          ? null
          : (await _readSnapshot(resolved.baseUri, effectiveSnapshotOptions))
              .snapshot;
      final baseline = request.compareAgainstSnapshotRef == null
          ? null
          : _snapshotStore.read(
              request.compareAgainstSnapshotRef!,
              sessionKey: sessionKey,
            );
      final snapshotRef =
          snapshot == null || !request.resultProfile.emitSnapshotRef
              ? null
              : _snapshotStore.put(sessionKey: sessionKey, snapshot: snapshot);

      return CockpitExecuteRemoteCommandResult(
        command: CockpitInteractiveCommandCore.fromResult(execution.result),
        artifacts: cockpitInteractiveArtifactsFromExecution(
          execution,
          request.resultProfile.artifacts,
        ),
        uiSummary: snapshot == null ||
                request.resultProfile.ui != CockpitInteractiveUiLevel.summary
            ? null
            : cockpitInteractiveSummarizeSnapshot(snapshot),
        snapshot: request.resultProfile.ui == CockpitInteractiveUiLevel.snapshot
            ? snapshot
            : null,
        diagnostics: snapshot == null
            ? null
            : cockpitInteractiveDiagnosticsFromSnapshot(
                snapshot,
                request.resultProfile.diagnostics,
              ),
        runtimeSteps: request.resultProfile.includeRuntimeSteps
            ? execution.runtimeSteps
                .map((step) => step.toJson())
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
}
