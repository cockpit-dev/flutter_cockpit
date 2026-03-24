import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

final class CockpitRemoteSessionClient {
  CockpitRemoteSessionClient({
    required Uri baseUri,
    HttpClient Function()? httpClientFactory,
    Duration? requestTimeout,
    Duration? artifactDownloadTimeout,
  })  : _baseUri = _normalizedBaseUri(baseUri),
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 30),
        _artifactDownloadTimeout =
            artifactDownloadTimeout ?? const Duration(seconds: 30);

  final Uri _baseUri;
  final HttpClient Function() _httpClientFactory;
  final Duration _requestTimeout;
  final Duration _artifactDownloadTimeout;

  Uri get baseUri => _baseUri;

  Future<CockpitRemoteSessionStatus> readStatus() async {
    final payload = await _send(method: 'GET', path: '/health');
    return CockpitRemoteSessionStatus.fromJson(payload);
  }

  Future<CockpitSnapshot> readSnapshot({
    CockpitSnapshotOptions options = const CockpitSnapshotOptions.live(),
  }) async {
    return (await readSnapshotDetailed(options: options)).snapshot;
  }

  Future<CockpitRemoteSnapshotResponse> readSnapshotDetailed({
    CockpitSnapshotOptions options = const CockpitSnapshotOptions.live(),
  }) async {
    final queryParameters = <String, String>{
      'profile': options.profile.jsonValue,
      'maxTargets': options.maxTargets.toString(),
      'maxAncestorsPerTarget': options.maxAncestorsPerTarget.toString(),
      'maxPropertiesPerTarget': options.maxPropertiesPerTarget.toString(),
      'maxRebuildEntries': options.maxRebuildEntries.toString(),
      'maxAccessibilityEntries': options.maxAccessibilityEntries.toString(),
      'includeStyleDetails': options.includeStyleDetails.toString(),
      'includeDiagnosticProperties':
          options.includeDiagnosticProperties.toString(),
      'emitArtifactWhenLarge': options.emitArtifactWhenLarge.toString(),
      'includeRebuildActivity': options.includeRebuildActivity.toString(),
      'includeAccessibilitySummary':
          options.includeAccessibilitySummary.toString(),
      'includeNetworkActivity': options.includeNetworkActivity.toString(),
      'maxNetworkEntries': options.maxNetworkEntries.toString(),
      'includeRuntimeActivity': options.includeRuntimeActivity.toString(),
      'maxRuntimeEntries': options.maxRuntimeEntries.toString(),
      if (options.networkQuery.method != null)
        'networkMethod': options.networkQuery.method!,
      if (options.networkQuery.uriContains != null)
        'networkUriContains': options.networkQuery.uriContains!,
      'networkOnlyFailures': options.networkQuery.onlyFailures.toString(),
      'runtimeOnlyErrors': options.runtimeQuery.onlyErrors.toString(),
      if (options.runtimeQuery.messageContains != null)
        'runtimeMessageContains': options.runtimeQuery.messageContains!,
      if (options.networkQuery.statusCodeAtLeast != null)
        'networkStatusCodeAtLeast':
            options.networkQuery.statusCodeAtLeast!.toString(),
    };
    final payload = await _send(
      method: 'GET',
      path: Uri(path: '/snapshot', queryParameters: queryParameters).toString(),
    );
    if (!payload.containsKey('snapshot')) {
      return CockpitRemoteSnapshotResponse(
        snapshot: CockpitSnapshot.fromJson(payload),
      );
    }

    final response = CockpitRemoteSnapshotResponse.fromJson(payload);
    final diagnosticsArtifactRef = response.snapshot.diagnosticsArtifactRef;
    if (diagnosticsArtifactRef == null) {
      return response;
    }
    final download = response.artifactDownloads.firstWhere(
      (candidate) =>
          candidate.artifact.relativePath ==
          diagnosticsArtifactRef.relativePath,
      orElse: () => const CockpitRemoteArtifactDownload(
        artifact: CockpitArtifactRef(role: '', relativePath: ''),
        downloadPath: '',
      ),
    );
    if (download.downloadPath.isEmpty) {
      return response;
    }

    final bytes = await _download(download.downloadPath);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<Object?, Object?>) {
      throw StateError(
        'Remote snapshot artifact must decode to a JSON object.',
      );
    }
    final fullSnapshot = CockpitSnapshot.fromJson(
      Map<String, Object?>.from(decoded),
    ).copyWith(diagnosticsArtifactRef: diagnosticsArtifactRef);
    return response.copyWith(snapshot: fullSnapshot);
  }

  Future<CockpitCommandResult> execute(CockpitCommand command) async {
    return (await executeDetailed(command)).result;
  }

  Future<bool> waitForUiIdle({
    Duration quietWindow = const Duration(milliseconds: 96),
    Duration timeout = const Duration(milliseconds: 1600),
    bool includeNetworkIdle = true,
  }) async {
    try {
      final result = await execute(
        CockpitCommand(
          commandId:
              'wait-ui-idle-${DateTime.now().toUtc().microsecondsSinceEpoch}',
          commandType: CockpitCommandType.waitForUiIdle,
          parameters: <String, Object?>{
            'quietWindowMs': quietWindow.inMilliseconds,
            'timeoutMs': timeout.inMilliseconds,
            'includeNetworkIdle': includeNetworkIdle,
          },
          timeoutMs: timeout.inMilliseconds,
        ),
      );
      return result.success;
    } on Object {
      return false;
    }
  }

  Future<CockpitCommandExecution> executeDetailed(
    CockpitCommand command,
  ) async {
    final payload = await _send(
      method: 'POST',
      path: '/commands/execute',
      body: command.toJson(),
    );
    if (payload.containsKey('result')) {
      return CockpitRemoteCommandResponse.fromJson(payload).toExecution();
    }
    return CockpitCommandExecution(
      result: CockpitCommandResult.fromJson(payload),
    );
  }

  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    final payload = await _send(
      method: 'POST',
      path: '/recording/start',
      body: request.toJson(),
    );
    return CockpitRecordingSession.fromJson(payload);
  }

  Future<CockpitRecordingResult> stopRecording() async {
    return (await stopRecordingDetailed()).result;
  }

  Future<CockpitRemoteRecordingResponse> stopRecordingDetailed() async {
    final payload = await _send(
      method: 'POST',
      path: '/recording/stop',
      body: const <String, Object?>{},
    );
    final response = CockpitRemoteRecordingResponse.fromJson(payload);
    final artifact = response.result.artifact;
    final download = artifact == null
        ? null
        : response.artifactDownloads.firstWhere(
            (candidate) =>
                candidate.artifact.relativePath == artifact.relativePath,
            orElse: () => const CockpitRemoteArtifactDownload(
              artifact: CockpitArtifactRef(role: '', relativePath: ''),
              downloadPath: '',
            ),
          );
    if (download == null || download.downloadPath.isEmpty) {
      return response;
    }

    final bytes = await _download(download.downloadPath);
    return CockpitRemoteRecordingResponse(
      result: CockpitRecordingResult(
        state: response.result.state,
        purpose: response.result.purpose,
        recordingKind: response.result.recordingKind,
        artifact: response.result.artifact,
        durationMs: response.result.durationMs,
        bytes: bytes,
        sourceFilePath: response.result.sourceFilePath,
        failureReason: response.result.failureReason,
      ),
      artifactDownloads: response.artifactDownloads,
    );
  }

  Future<Map<String, Object?>> _send({
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) async {
    final client = _httpClientFactory();
    try {
      return await (() async {
        final request = await client.openUrl(method, _baseUri.resolve(path));
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }

        final response = await request.close();
        final payload = await utf8.decoder.bind(response).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            'Remote session request failed: ${response.statusCode} $payload',
          );
        }
        if (payload.isEmpty) {
          throw StateError('Remote session returned an empty response.');
        }

        final decoded = jsonDecode(payload);
        if (decoded is! Map<Object?, Object?>) {
          throw StateError('Remote session response must be a JSON object.');
        }
        return Map<String, Object?>.from(decoded);
      })()
          .timeout(
        _requestTimeout,
        onTimeout: () {
          client.close(force: true);
          throw TimeoutException(
            'Remote session request timed out for $method $path.',
          );
        },
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<List<int>> _download(String relativePath) async {
    final client = _httpClientFactory();
    try {
      return await (() async {
        final request = await client.getUrl(_baseUri.resolve(relativePath));
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final payload = await utf8.decoder.bind(response).join();
          throw StateError(
            'Remote session artifact download failed: ${response.statusCode} $payload',
          );
        }

        final bytes = await response.fold<List<int>>(<int>[], (bytes, chunk) {
          final combined = List<int>.of(bytes);
          combined.addAll(chunk);
          return combined;
        });
        return bytes;
      })()
          .timeout(
        _artifactDownloadTimeout,
        onTimeout: () {
          client.close(force: true);
          throw TimeoutException(
            'Remote session artifact download timed out for $relativePath.',
          );
        },
      );
    } finally {
      client.close(force: true);
    }
  }

  static Uri _normalizedBaseUri(Uri uri) {
    return uri.path.isEmpty
        ? uri.replace(path: '/')
        : uri.path.endsWith('/')
            ? uri
            : uri.replace(path: '${uri.path}/');
  }
}
