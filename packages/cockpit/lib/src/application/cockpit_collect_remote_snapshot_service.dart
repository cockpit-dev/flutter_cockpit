export 'cockpit_application_service_exception.dart';

import 'package:cockpit_protocol/cockpit_protocol.dart';

import 'cockpit_session_reference_resolver.dart';
import '../session/cockpit_remote_session_handle.dart';
import '../remote/cockpit_remote_session_client.dart';

typedef CockpitRemoteSnapshotReader =
    Future<CockpitRemoteSnapshotResponse> Function(
      Uri baseUri,
      CockpitSnapshotOptions options,
    );

final class CockpitCollectRemoteSnapshotRequest {
  const CockpitCollectRemoteSnapshotRequest({
    this.baseUri,
    this.sessionHandle,
    this.sessionHandlePath,
    this.androidDeviceId,
    this.iosDeviceId,
    this.options = const CockpitSnapshotOptions.live(),
    this.downloadDiagnosticsArtifacts = false,
  });

  final Uri? baseUri;
  final CockpitRemoteSessionHandle? sessionHandle;
  final String? sessionHandlePath;
  final String? androidDeviceId;
  final String? iosDeviceId;
  final CockpitSnapshotOptions options;
  final bool downloadDiagnosticsArtifacts;
}

final class CockpitCollectRemoteSnapshotResult {
  const CockpitCollectRemoteSnapshotResult({
    required this.snapshot,
    required this.effectiveOptions,
    this.sessionHandle,
    this.warnings = const <String>[],
  });

  final CockpitSnapshot snapshot;
  final CockpitSnapshotOptions effectiveOptions;
  final CockpitRemoteSessionHandle? sessionHandle;
  final List<String> warnings;

  Map<String, Object?> toJson() => <String, Object?>{
    'snapshot': snapshot.toJson(),
    'effectiveOptions': effectiveOptions.toJson(),
    if (sessionHandle != null) 'sessionHandle': sessionHandle!.toJson(),
    'warnings': warnings,
  };
}

final class CockpitCollectRemoteSnapshotService {
  CockpitCollectRemoteSnapshotService({
    CockpitRemoteSnapshotReader? snapshotReader,
    CockpitSessionReferenceResolver? sessionReferenceResolver,
  }) : _snapshotReader = snapshotReader,
       _sessionReferenceResolver =
           sessionReferenceResolver ?? CockpitSessionReferenceResolver();

  final CockpitRemoteSnapshotReader? _snapshotReader;
  final CockpitSessionReferenceResolver _sessionReferenceResolver;

  Future<CockpitCollectRemoteSnapshotResult> collect(
    CockpitCollectRemoteSnapshotRequest request,
  ) async {
    final resolved = await _sessionReferenceResolver.resolve(
      baseUri: request.baseUri,
      sessionHandle: request.sessionHandle,
      sessionHandlePath: request.sessionHandlePath,
      androidDeviceId: request.androidDeviceId,
      iosDeviceId: request.iosDeviceId,
    );
    final effectiveOptions = _normalizeOptions(request.options);
    final response = await _readSnapshot(
      resolved.baseUri,
      effectiveOptions,
      downloadDiagnosticsArtifacts: request.downloadDiagnosticsArtifacts,
    );

    return CockpitCollectRemoteSnapshotResult(
      snapshot: response.snapshot,
      effectiveOptions: effectiveOptions,
      sessionHandle: resolved.sessionHandle,
    );
  }

  Future<CockpitRemoteSnapshotResponse> _readSnapshot(
    Uri baseUri,
    CockpitSnapshotOptions options, {
    required bool downloadDiagnosticsArtifacts,
  }) {
    final reader = _snapshotReader;
    if (reader != null) {
      return reader(baseUri, options);
    }
    return CockpitRemoteSessionClient(
      baseUri: baseUri,
      downloadDiagnosticsArtifacts: downloadDiagnosticsArtifacts,
    ).readSnapshotDetailed(options: options);
  }

  CockpitSnapshotOptions _normalizeOptions(CockpitSnapshotOptions options) {
    var effectiveOptions = options;
    if (!options.networkQuery.isEmpty && !options.includeNetworkActivity) {
      effectiveOptions = effectiveOptions.copyWith(
        includeNetworkActivity: true,
      );
    }
    return effectiveOptions;
  }
}
