import 'dart:async';

export 'cockpit_application_service_exception.dart';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_handle.dart';
import 'cockpit_interactive_result_data.dart';
import 'cockpit_interactive_result_profile.dart';
import 'cockpit_interactive_snapshot_store.dart';
import 'cockpit_session_reference_resolver.dart';

typedef CockpitRemoteSnapshotDetailedReader
    = Future<CockpitRemoteSnapshotResponse> Function(
  Uri baseUri,
  CockpitSnapshotOptions options,
);

final class CockpitReadRemoteSnapshotRequest {
  const CockpitReadRemoteSnapshotRequest({
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
    this.resultProfile = const CockpitInteractiveResultProfile.standard(),
    this.snapshotOptions,
    this.compareAgainstSnapshotRef,
  });

  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
  final CockpitInteractiveResultProfile resultProfile;
  final CockpitSnapshotOptions? snapshotOptions;
  final String? compareAgainstSnapshotRef;
}

final class CockpitReadRemoteSnapshotResult {
  const CockpitReadRemoteSnapshotResult({
    required this.routeName,
    required this.diagnosticLevel,
    required this.truncated,
    this.uiSummary,
    this.snapshot,
    this.diagnostics,
    this.delta,
    this.snapshotRef,
    this.sessionHandle,
    this.effectiveSnapshotOptions,
  });

  final String? routeName;
  final String diagnosticLevel;
  final bool truncated;
  final CockpitInteractiveSnapshotSummary? uiSummary;
  final CockpitSnapshot? snapshot;
  final Map<String, Object?>? diagnostics;
  final CockpitInteractiveSnapshotDelta? delta;
  final String? snapshotRef;
  final CockpitRemoteSessionHandle? sessionHandle;
  final CockpitSnapshotOptions? effectiveSnapshotOptions;

  Map<String, Object?> toJson() => <String, Object?>{
        if (routeName != null) 'routeName': routeName,
        'diagnosticLevel': diagnosticLevel,
        'truncated': truncated,
        if (uiSummary != null) 'uiSummary': uiSummary!.toJson(),
        if (snapshot != null) 'snapshot': snapshot!.toJson(),
        if (diagnostics != null) 'diagnostics': diagnostics,
        if (delta != null) 'delta': delta!.toJson(),
        if (snapshotRef != null) 'snapshotRef': snapshotRef,
        if (sessionHandle != null) 'sessionHandle': sessionHandle!.toJson(),
        if (effectiveSnapshotOptions != null)
          'effectiveSnapshotOptions': effectiveSnapshotOptions!.toJson(),
      };
}

final class CockpitReadRemoteSnapshotService {
  CockpitReadRemoteSnapshotService({
    CockpitRemoteSnapshotDetailedReader? readSnapshot,
    CockpitSessionReferenceResolver? sessionReferenceResolver,
    CockpitInteractiveSnapshotStore? snapshotStore,
  })  : _readSnapshot = readSnapshot ??
            ((baseUri, options) => CockpitRemoteSessionClient(
                  baseUri: baseUri,
                ).readSnapshotDetailed(options: options)),
        _sessionReferenceResolver =
            sessionReferenceResolver ?? CockpitSessionReferenceResolver(),
        _snapshotStore = snapshotStore ?? CockpitInteractiveSnapshotStore();

  final CockpitRemoteSnapshotDetailedReader _readSnapshot;
  final CockpitSessionReferenceResolver _sessionReferenceResolver;
  final CockpitInteractiveSnapshotStore _snapshotStore;

  Future<CockpitReadRemoteSnapshotResult> read(
    CockpitReadRemoteSnapshotRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.androidDeviceId,
    );
    final effectiveSnapshotOptions =
        request.resultProfile.resolveSnapshotOptions(
      request.snapshotOptions,
    );
    final snapshot = (await cockpitReadRemoteSnapshotConsistently(
      baseUri: resolved.baseUri,
      options: effectiveSnapshotOptions,
      readSnapshot: _readSnapshot,
    ))
        .snapshot;
    final sessionKey = resolved.baseUri.toString();
    final baseline = request.compareAgainstSnapshotRef == null
        ? null
        : _snapshotStore.read(
            request.compareAgainstSnapshotRef!,
            sessionKey: sessionKey,
          );
    final snapshotRef = request.resultProfile.emitSnapshotRef
        ? _snapshotStore.put(sessionKey: sessionKey, snapshot: snapshot)
        : null;

    return CockpitReadRemoteSnapshotResult(
      routeName: snapshot.routeName,
      diagnosticLevel: snapshot.diagnosticLevel.jsonValue,
      truncated: snapshot.truncated,
      uiSummary: request.resultProfile.ui == CockpitInteractiveUiLevel.summary
          ? cockpitInteractiveSummarizeSnapshot(snapshot)
          : null,
      snapshot: request.resultProfile.ui == CockpitInteractiveUiLevel.snapshot
          ? snapshot
          : null,
      diagnostics: cockpitInteractiveDiagnosticsFromSnapshot(
        snapshot,
        request.resultProfile.diagnostics,
      ),
      delta: baseline == null
          ? null
          : cockpitInteractiveDiffSnapshots(baseline.snapshot, snapshot),
      snapshotRef: snapshotRef,
      sessionHandle: resolved.sessionHandle,
      effectiveSnapshotOptions: effectiveSnapshotOptions,
    );
  }
}

Future<CockpitRemoteSnapshotResponse> cockpitReadRemoteSnapshotConsistently({
  required Uri baseUri,
  required CockpitSnapshotOptions options,
  required CockpitRemoteSnapshotDetailedReader readSnapshot,
}) async {
  var response = await readSnapshot(baseUri, options);
  if (!_isLikelyTransitionEmptySnapshot(response.snapshot)) {
    return response;
  }

  for (final delay in _transitionSnapshotRetryDelays) {
    await Future<void>.delayed(delay);
    response = await readSnapshot(baseUri, options);
    if (!_isLikelyTransitionEmptySnapshot(response.snapshot)) {
      break;
    }
  }

  return response;
}

const List<Duration> _transitionSnapshotRetryDelays = <Duration>[
  Duration(milliseconds: 120),
  Duration(milliseconds: 240),
];

bool _isLikelyTransitionEmptySnapshot(CockpitSnapshot snapshot) {
  final routeName = snapshot.routeName;
  if (routeName == null || routeName.isEmpty) {
    return false;
  }
  if (snapshot.visibleTargets.isNotEmpty) {
    return false;
  }

  final summary = snapshot.summary;
  if (summary != null && summary.visibleTargetCount > 0) {
    return false;
  }

  final accessibility = snapshot.accessibility;
  if (accessibility != null && accessibility.totalAccessibleTargetCount > 0) {
    return false;
  }

  return true;
}
