export 'cockpit_application_service_exception.dart';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_launcher.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_result_profile.dart';
import 'cockpit_interactive_snapshot_store.dart';
import 'cockpit_read_remote_snapshot_service.dart';
import 'cockpit_session_reference_resolver.dart';

typedef CockpitRemoteStatusReader = Future<CockpitRemoteSessionStatus> Function(
  Uri baseUri,
);

final class CockpitReadRemoteStatusRequest {
  const CockpitReadRemoteStatusRequest({
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
    this.resultProfile = const CockpitInteractiveResultProfile.minimal(),
    this.snapshotOptions,
  });

  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
  final CockpitInteractiveResultProfile resultProfile;
  final CockpitSnapshotOptions? snapshotOptions;
}

final class CockpitReadRemoteStatusResult {
  const CockpitReadRemoteStatusResult({
    required this.sessionId,
    required this.platform,
    required this.transportType,
    required this.currentRouteName,
    required this.capabilities,
    required this.recordingCapabilities,
    this.activeRecording,
    this.environment,
    this.uiSummary,
    this.snapshot,
    this.snapshotRef,
    this.sessionHandle,
    this.effectiveSnapshotOptions,
  });

  final String sessionId;
  final String platform;
  final String transportType;
  final String? currentRouteName;
  final CockpitCapabilities capabilities;
  final CockpitRecordingCapabilities recordingCapabilities;
  final CockpitRecordingSession? activeRecording;
  final CockpitEnvironment? environment;
  final CockpitInteractiveSnapshotSummary? uiSummary;
  final CockpitSnapshot? snapshot;
  final String? snapshotRef;
  final CockpitRemoteSessionHandle? sessionHandle;
  final CockpitSnapshotOptions? effectiveSnapshotOptions;

  Map<String, Object?> toJson() => <String, Object?>{
        'sessionId': sessionId,
        'platform': platform,
        'transportType': transportType,
        if (currentRouteName != null) 'currentRouteName': currentRouteName,
        'capabilities': capabilities.toJson(),
        'recordingCapabilities': recordingCapabilities.toJson(),
        if (activeRecording != null)
          'activeRecording': activeRecording!.toJson(),
        if (environment != null) 'environment': environment!.toJson(),
        if (uiSummary != null) 'uiSummary': uiSummary!.toJson(),
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (snapshotRef != null) 'snapshotRef': snapshotRef,
        if (sessionHandle != null) 'sessionHandle': sessionHandle!.toJson(),
        if (effectiveSnapshotOptions != null)
          'effectiveSnapshotOptions': effectiveSnapshotOptions!.toJson(),
      };
}

final class CockpitReadRemoteStatusService {
  CockpitReadRemoteStatusService({
    CockpitRemoteStatusReader? readStatus,
    CockpitRemoteSnapshotDetailedReader? readSnapshot,
    CockpitSessionReferenceResolver? sessionReferenceResolver,
    CockpitInteractiveSnapshotStore? snapshotStore,
  })  : _readStatus = readStatus ?? cockpitReadRemoteSessionStatus,
        _readSnapshot = readSnapshot ??
            ((baseUri, options) => CockpitRemoteSessionClient(
                  baseUri: baseUri,
                ).readSnapshotDetailed(options: options)),
        _sessionReferenceResolver =
            sessionReferenceResolver ?? CockpitSessionReferenceResolver(),
        _snapshotStore = snapshotStore ?? CockpitInteractiveSnapshotStore();

  final CockpitRemoteStatusReader _readStatus;
  final CockpitRemoteSnapshotDetailedReader _readSnapshot;
  final CockpitSessionReferenceResolver _sessionReferenceResolver;
  final CockpitInteractiveSnapshotStore _snapshotStore;

  Future<CockpitReadRemoteStatusResult> read(
    CockpitReadRemoteStatusRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.androidDeviceId,
    );
    final status = await _readStatus(resolved.baseUri);
    final needsRichSnapshot = request.resultProfile.ui !=
            CockpitInteractiveUiLevel.none ||
        request.resultProfile.emitSnapshotRef ||
        request.resultProfile.snapshotProfile != CockpitSnapshotProfile.live ||
        request.resultProfile.diagnostics !=
            CockpitInteractiveDiagnosticsLevel.none;
    final effectiveSnapshotOptions = needsRichSnapshot
        ? request.resultProfile.resolveSnapshotOptions(request.snapshotOptions)
        : null;
    final snapshot = effectiveSnapshotOptions == null
        ? status.snapshot
        : (await _readSnapshot(resolved.baseUri, effectiveSnapshotOptions))
            .snapshot;
    final snapshotRef = request.resultProfile.emitSnapshotRef
        ? _snapshotStore.put(
            sessionKey: resolved.baseUri.toString(),
            snapshot: snapshot,
          )
        : null;

    return CockpitReadRemoteStatusResult(
      sessionId: status.sessionId,
      platform: status.platform,
      transportType: status.transportType,
      currentRouteName: snapshot.routeName ?? status.currentRouteName,
      capabilities: status.capabilities,
      recordingCapabilities: status.recordingCapabilities,
      activeRecording: status.activeRecording,
      environment: status.environment,
      uiSummary: request.resultProfile.ui == CockpitInteractiveUiLevel.summary
          ? cockpitInteractiveSummarizeSnapshot(snapshot)
          : null,
      snapshot: request.resultProfile.ui == CockpitInteractiveUiLevel.snapshot
          ? snapshot
          : null,
      snapshotRef: snapshotRef,
      sessionHandle: resolved.sessionHandle,
      effectiveSnapshotOptions: effectiveSnapshotOptions,
    );
  }
}
