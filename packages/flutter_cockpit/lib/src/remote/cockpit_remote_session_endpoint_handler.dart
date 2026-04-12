import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../control/cockpit_command.dart';
import '../control/cockpit_command_execution.dart';
import '../model/cockpit_artifact_ref.dart';
import '../model/cockpit_step_record.dart';
import '../recording/cockpit_recording_request.dart';
import '../recording/cockpit_recording_result.dart';
import '../recording/cockpit_recording_session.dart';
import '../runtime/cockpit_snapshot.dart';
import '../runtime/cockpit_snapshot_options.dart';
import 'cockpit_remote_artifact_download.dart';
import 'cockpit_remote_command_response.dart';
import 'cockpit_remote_recording_response.dart';
import 'cockpit_remote_session_configuration.dart';
import 'cockpit_remote_session_status.dart';
import 'cockpit_remote_snapshot_response.dart';

typedef CockpitRemoteSessionStatusProvider = Future<CockpitRemoteSessionStatus>
    Function();
typedef CockpitRemoteSessionSnapshotProvider = FutureOr<CockpitSnapshot>
    Function({
  required CockpitSnapshotOptions options,
});
typedef CockpitRemoteSessionCommandExecutor = Future<CockpitCommandExecution>
    Function(CockpitCommand command);
typedef CockpitRemoteRuntimeStepDrainer = FutureOr<List<CockpitStepRecord>>
    Function({required bool clear});
typedef CockpitRemoteRecordingStarter = Future<CockpitRecordingSession>
    Function(CockpitRecordingRequest request);
typedef CockpitRemoteRecordingStopper = Future<CockpitRecordingResult>
    Function();

final class CockpitRemoteSessionEndpointRequest {
  const CockpitRemoteSessionEndpointRequest({
    required this.method,
    required this.uri,
    this.jsonBody = const <String, Object?>{},
  });

  final String method;
  final Uri uri;
  final Map<String, Object?> jsonBody;
}

final class CockpitRemoteSessionEndpointResponse {
  const CockpitRemoteSessionEndpointResponse._({
    required this.statusCode,
    required this.contentType,
    this.jsonBody,
    this.binaryBody,
  });

  const CockpitRemoteSessionEndpointResponse.json(
    Map<String, Object?> body, {
    int statusCode = HttpStatus.ok,
  }) : this._(
          statusCode: statusCode,
          contentType: 'application/json',
          jsonBody: body,
        );

  const CockpitRemoteSessionEndpointResponse.binary(
    List<int> bytes, {
    int statusCode = HttpStatus.ok,
    String contentType = 'application/octet-stream',
  }) : this._(
          statusCode: statusCode,
          contentType: contentType,
          binaryBody: bytes,
        );

  final int statusCode;
  final String contentType;
  final Map<String, Object?>? jsonBody;
  final List<int>? binaryBody;
}

final class _RemoteArtifactEntry {
  const _RemoteArtifactEntry({this.bytes});

  final List<int>? bytes;
}

final class CockpitRemoteSessionEndpointHandler {
  CockpitRemoteSessionEndpointHandler({
    required CockpitRemoteSessionConfiguration configuration,
    required CockpitRemoteSessionStatusProvider statusProvider,
    required CockpitRemoteSessionSnapshotProvider snapshotProvider,
    required CockpitRemoteSessionCommandExecutor commandExecutor,
    CockpitRemoteRuntimeStepDrainer? runtimeStepDrainer,
    required CockpitRemoteRecordingStarter startRecording,
    required CockpitRemoteRecordingStopper stopRecording,
  })  : _configuration = configuration,
        _statusProvider = statusProvider,
        _snapshotProvider = snapshotProvider,
        _commandExecutor = commandExecutor,
        _runtimeStepDrainer = runtimeStepDrainer,
        _startRecording = startRecording,
        _stopRecording = stopRecording;

  final CockpitRemoteSessionConfiguration _configuration;
  final CockpitRemoteSessionStatusProvider _statusProvider;
  final CockpitRemoteSessionSnapshotProvider _snapshotProvider;
  final CockpitRemoteSessionCommandExecutor _commandExecutor;
  final CockpitRemoteRuntimeStepDrainer? _runtimeStepDrainer;
  final CockpitRemoteRecordingStarter _startRecording;
  final CockpitRemoteRecordingStopper _stopRecording;
  final Map<String, _RemoteArtifactEntry> _downloadableArtifacts =
      <String, _RemoteArtifactEntry>{};

  Future<CockpitRemoteSessionEndpointResponse> handle(
    CockpitRemoteSessionEndpointRequest request,
  ) async {
    try {
      final routePath = _routePathFor(request.uri.path);
      switch ((request.method, routePath)) {
        case ('GET', '/health'):
          return CockpitRemoteSessionEndpointResponse.json(
            (await _statusProvider()).toJson(),
          );
        case ('GET', '/snapshot'):
          final snapshotOptions = _snapshotOptionsFromQuery(
            request.uri.queryParameters,
          );
          final snapshot = await _snapshotProvider(options: snapshotOptions);
          final snapshotResponse = _snapshotResponseFor(
            snapshot,
            options: snapshotOptions,
          );
          return CockpitRemoteSessionEndpointResponse.json(
            snapshotResponse.artifactDownloads.isEmpty
                ? snapshotResponse.snapshot.toJson()
                : snapshotResponse.toJson(),
          );
        case ('GET', '/artifacts/download'):
          return _artifactResponseFor(request);
        case ('POST', '/commands/execute'):
          final command = CockpitCommand.fromJson(request.jsonBody);
          await _drainRuntimeSteps(clear: true);
          final execution = await _commandExecutor(command);
          final runtimeSteps = await _drainRuntimeSteps(clear: true);
          final responsePayload = CockpitRemoteCommandResponse.fromExecution(
            CockpitCommandExecution(
              result: execution.result,
              artifactPayloads: execution.artifactPayloads,
              artifactSourcePaths: execution.artifactSourcePaths,
              runtimeSteps: <CockpitStepRecord>[
                ...execution.runtimeSteps,
                ...runtimeSteps,
              ],
            ),
          ).toJson();
          return CockpitRemoteSessionEndpointResponse.json(responsePayload);
        case ('POST', '/recording/start'):
          final recording = await _startRecording(
            CockpitRecordingRequest.fromJson(request.jsonBody),
          );
          return CockpitRemoteSessionEndpointResponse.json(recording.toJson());
        case ('POST', '/recording/stop'):
          final result = await _stopRecording();
          return CockpitRemoteSessionEndpointResponse.json(
            _recordingResponseFor(result).toJson(),
          );
        default:
          return const CockpitRemoteSessionEndpointResponse.json(
            <String, Object?>{
              'error': 'notFound',
              'message': 'Unsupported remote session endpoint.',
            },
            statusCode: HttpStatus.notFound,
          );
      }
    } on FormatException catch (error) {
      return CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'invalidPayload',
          'message': error.message,
        },
        statusCode: HttpStatus.badRequest,
      );
    } catch (error) {
      return CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'serverError',
          'message': error.toString(),
        },
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  Future<List<CockpitStepRecord>> _drainRuntimeSteps({
    required bool clear,
  }) async {
    final drainer = _runtimeStepDrainer;
    if (drainer == null) {
      return const <CockpitStepRecord>[];
    }
    return List<CockpitStepRecord>.unmodifiable(
      await Future<List<CockpitStepRecord>>.value(drainer(clear: clear)),
    );
  }

  CockpitSnapshotOptions _snapshotOptionsFromQuery(
    Map<String, String> queryParameters,
  ) {
    if (queryParameters.isEmpty) {
      return const CockpitSnapshotOptions.live();
    }

    final json = <String, Object?>{};
    final profile = queryParameters['profile'];
    if (profile != null && profile.isNotEmpty) {
      json['profile'] = profile;
    }

    for (final key in <String>[
      'maxTargets',
      'maxAncestorsPerTarget',
      'maxPropertiesPerTarget',
      'maxRebuildEntries',
      'maxAccessibilityEntries',
      'maxNetworkEntries',
      'networkStatusCodeAtLeast',
      'maxRuntimeEntries',
    ]) {
      final rawValue = queryParameters[key];
      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }
      json[key] = int.tryParse(rawValue);
    }

    for (final key in <String>[
      'includeStyleDetails',
      'includeDiagnosticProperties',
      'emitArtifactWhenLarge',
      'includeRebuildActivity',
      'includeAccessibilitySummary',
      'includeNetworkActivity',
      'networkOnlyFailures',
      'includeRuntimeActivity',
      'runtimeOnlyErrors',
    ]) {
      final rawValue = queryParameters[key];
      if (rawValue == null || rawValue.isEmpty) {
        continue;
      }
      json[key] = rawValue.toLowerCase() == 'true';
    }

    final networkQuery = <String, Object?>{};
    final networkMethod = queryParameters['networkMethod'];
    if (networkMethod != null && networkMethod.isNotEmpty) {
      networkQuery['method'] = networkMethod;
    }
    final networkUriContains = queryParameters['networkUriContains'];
    if (networkUriContains != null && networkUriContains.isNotEmpty) {
      networkQuery['uriContains'] = networkUriContains;
    }
    if (json.containsKey('networkOnlyFailures')) {
      networkQuery['onlyFailures'] = json.remove('networkOnlyFailures');
    }
    if (json.containsKey('networkStatusCodeAtLeast')) {
      networkQuery['statusCodeAtLeast'] = json.remove(
        'networkStatusCodeAtLeast',
      );
    }
    if (networkQuery.isNotEmpty) {
      json['networkQuery'] = networkQuery;
    }

    final runtimeQuery = <String, Object?>{};
    final runtimeMessageContains = queryParameters['runtimeMessageContains'];
    if (runtimeMessageContains != null && runtimeMessageContains.isNotEmpty) {
      runtimeQuery['messageContains'] = runtimeMessageContains;
    }
    if (json.containsKey('runtimeOnlyErrors')) {
      runtimeQuery['onlyErrors'] = json.remove('runtimeOnlyErrors');
    }
    if (runtimeQuery.isNotEmpty) {
      json['runtimeQuery'] = runtimeQuery;
    }

    return CockpitSnapshotOptions.fromJson(json);
  }

  String _routePathFor(String path) {
    final prefix = _configuration.normalizedRoutePrefix;
    if (prefix.isEmpty) {
      return path;
    }
    if (path == prefix) {
      return '/';
    }
    if (path.startsWith('$prefix/')) {
      return path.substring(prefix.length);
    }
    return path;
  }

  CockpitRemoteRecordingResponse _recordingResponseFor(
    CockpitRecordingResult result,
  ) {
    final artifact = result.artifact;
    if (artifact == null) {
      return CockpitRemoteRecordingResponse(result: result);
    }

    final artifactEntry = _artifactEntryFor(result);
    if (artifactEntry == null) {
      return CockpitRemoteRecordingResponse(result: result);
    }

    _downloadableArtifacts[artifact.relativePath] = artifactEntry;
    return CockpitRemoteRecordingResponse(
      result: result,
      artifactDownloads: <CockpitRemoteArtifactDownload>[
        CockpitRemoteArtifactDownload(
          artifact: artifact,
          downloadPath:
              '/artifacts/download?path=${Uri.encodeQueryComponent(artifact.relativePath)}',
        ),
      ],
    );
  }

  CockpitRemoteSnapshotResponse _snapshotResponseFor(
    CockpitSnapshot snapshot, {
    required CockpitSnapshotOptions options,
  }) {
    if (!options.emitArtifactWhenLarge) {
      return CockpitRemoteSnapshotResponse(snapshot: snapshot);
    }
    final snapshotBytes = utf8.encode(
      jsonEncode(_compactJsonValue(snapshot.toJson())),
    );
    if (snapshotBytes.length <= 16384) {
      return CockpitRemoteSnapshotResponse(snapshot: snapshot);
    }

    final artifactRef = snapshot.diagnosticsArtifactRef ??
        CockpitArtifactRef(
          role: 'diagnostics',
          relativePath:
              'diagnostics/remote_snapshot_${DateTime.now().toUtc().microsecondsSinceEpoch}.json',
        );
    _downloadableArtifacts[artifactRef.relativePath] = _RemoteArtifactEntry(
      bytes: List<int>.unmodifiable(snapshotBytes),
    );

    return CockpitRemoteSnapshotResponse(
      snapshot: _summarizedSnapshot(
        snapshot,
      ).copyWith(diagnosticsArtifactRef: artifactRef),
      artifactDownloads: <CockpitRemoteArtifactDownload>[
        CockpitRemoteArtifactDownload(
          artifact: artifactRef,
          downloadPath:
              '/artifacts/download?path=${Uri.encodeQueryComponent(artifactRef.relativePath)}',
        ),
      ],
    );
  }

  CockpitSnapshot _summarizedSnapshot(CockpitSnapshot snapshot) {
    return CockpitSnapshot(
      routeName: snapshot.routeName,
      visibleTargets: snapshot.visibleTargets
          .map(
            (target) => CockpitSnapshotTarget(
              registrationId: target.registrationId,
              cockpitId: target.cockpitId,
              semanticId: target.semanticId,
              keyValue: target.keyValue,
              text: target.text,
              tooltip: target.tooltip,
              typeName: target.typeName,
              routeName: target.routeName,
              supportedCommands: target.supportedCommands,
            ),
          )
          .toList(growable: false),
      diagnosticLevel: snapshot.diagnosticLevel,
      truncated: snapshot.truncated,
      summary: snapshot.summary,
      network: snapshot.network,
    );
  }

  _RemoteArtifactEntry? _artifactEntryFor(CockpitRecordingResult result) {
    final bytes = result.bytes;
    if (bytes != null) {
      return _RemoteArtifactEntry(bytes: List<int>.unmodifiable(bytes));
    }

    final sourceFilePath = result.sourceFilePath;
    if (sourceFilePath == null || sourceFilePath.isEmpty) {
      return null;
    }
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      return null;
    }
    return _RemoteArtifactEntry(
      bytes: List<int>.unmodifiable(sourceFile.readAsBytesSync()),
    );
  }

  Future<CockpitRemoteSessionEndpointResponse> _artifactResponseFor(
    CockpitRemoteSessionEndpointRequest request,
  ) async {
    final relativePath = request.uri.queryParameters['path'];
    if (relativePath == null || relativePath.isEmpty) {
      return const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'invalidArtifactPath',
          'message': 'Artifact path is required.',
        },
        statusCode: HttpStatus.badRequest,
      );
    }

    final entry = _downloadableArtifacts[relativePath];
    if (entry == null) {
      return const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'artifactNotFound',
          'message': 'Unknown artifact path.',
        },
        statusCode: HttpStatus.notFound,
      );
    }

    return CockpitRemoteSessionEndpointResponse.binary(
      entry.bytes ?? const <int>[],
    );
  }
}

Object? _compactJsonValue(Object? value) {
  if (value is Map<Object?, Object?>) {
    final compacted = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        continue;
      }
      final compactedValue = _compactJsonValue(entry.value);
      if (compactedValue != null) {
        compacted[key] = compactedValue;
      }
    }
    return compacted;
  }
  if (value is List<Object?>) {
    return value.map(_compactJsonValue).toList(growable: false);
  }
  return value;
}
