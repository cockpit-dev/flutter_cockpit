import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit/flutter_cockpit_remote_bridge.dart';

import 'cockpit_browser_recording_adapter_resolver.dart';
import '../remote/cockpit_remote_command_timeout_budget.dart';
import '../recording/cockpit_host_recording_adapter.dart';
import '../development/cockpit_development_session_handle.dart';

typedef CockpitBridgeArtifactTempFileFactory =
    Future<File> Function(String basename);

CockpitWebRemoteSessionBridgeServer? cockpitCreateWebRemoteSessionBridgeServer({
  required CockpitDevelopmentSessionHandle handle,
}) {
  if (handle.platform != 'web') {
    return null;
  }
  return CockpitWebRemoteSessionBridgeServer(
    bindHost: handle.baseUri.host,
    bindPort: handle.baseUri.port,
    routePrefix: handle.baseUri.path == '/' ? '' : handle.baseUri.path,
    recordingAdapter: cockpitResolveBrowserRecordingAdapter(
      deviceId: handle.deviceId,
    ),
  );
}

final class CockpitWebRemoteSessionBridgeServer {
  CockpitWebRemoteSessionBridgeServer({
    required this.bindHost,
    required this.bindPort,
    this.routePrefix = '',
    this.recordingAdapter,
    CockpitBridgeArtifactTempFileFactory? artifactTempFileFactory,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _artifactTempFileFactory =
           artifactTempFileFactory ?? _defaultBridgeArtifactTempFileFactory;

  final String bindHost;
  final int bindPort;
  final String routePrefix;
  final CockpitHostRecordingAdapter? recordingAdapter;
  final Duration requestTimeout;
  final CockpitBridgeArtifactTempFileFactory _artifactTempFileFactory;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _requestSubscription;
  WebSocket? _socket;
  StreamSubscription<Object?>? _socketSubscription;
  final Map<String, Completer<CockpitRemoteBridgeResponse>> _pending =
      <String, Completer<CockpitRemoteBridgeResponse>>{};
  final Map<String, _BridgeArtifactEntry> _localArtifacts =
      <String, _BridgeArtifactEntry>{};
  Uri? _baseUri;
  CockpitRecordingSession? _activeRecordingSession;

  Uri get baseUri => _baseUri!;
  Uri get connectUri => baseUri.replace(
    scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
    path: _joinPath(_normalizedRoutePrefix, 'connect'),
  );

  Future<void> start() async {
    if (_server != null) {
      return;
    }
    final server = await HttpServer.bind(bindHost, bindPort);
    _server = server;
    _baseUri = Uri(
      scheme: 'http',
      host: bindHost,
      port: server.port,
      path: _normalizedRoutePrefix,
    );
    _requestSubscription = server.listen(_handleRequest);
  }

  Future<void> close() async {
    _failPending(StateError('Bridge server closed.'));
    await _bestEffortStopActiveRecording();
    await _socketSubscription?.cancel();
    await _socket?.close();
    await _requestSubscription?.cancel();
    await _server?.close(force: true);
    await _deleteGeneratedArtifacts();
    _socketSubscription = null;
    _socket = null;
    _requestSubscription = null;
    _server = null;
    _baseUri = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (WebSocketTransformer.isUpgradeRequest(request) &&
          _routePathFor(request.uri.path) == '/connect') {
        await _handleConnect(request);
        return;
      }

      final response = await _resolveResponse(request);
      await _writeResponse(request.response, response);
    } on FormatException catch (error) {
      await _writeResponse(
        request.response,
        CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
          'error': 'invalidPayload',
          'message': error.message,
        }, statusCode: HttpStatus.badRequest),
      );
    } catch (error) {
      await _writeResponse(
        request.response,
        CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
          'error': 'serverError',
          'message': error.toString(),
        }, statusCode: HttpStatus.internalServerError),
      );
    }
  }

  Future<void> _handleConnect(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    await _socketSubscription?.cancel();
    await _socket?.close();
    _socket = socket;
    _socketSubscription = socket.listen(
      (payload) {
        _handleSocketPayload(payload);
      },
      onDone: () {
        _socketSubscription = null;
        _socket = null;
        _failPending(StateError('Bridge client disconnected.'));
      },
      onError: (Object error, StackTrace stackTrace) {
        _socketSubscription = null;
        _socket = null;
        _failPending(error);
      },
      cancelOnError: true,
    );
  }

  void _handleSocketPayload(Object? payload) {
    if (payload == null) {
      return;
    }
    try {
      final decoded = jsonDecode('$payload');
      if (decoded is! Map<Object?, Object?>) {
        _completePendingWithBridgeError(
          statusCode: HttpStatus.badGateway,
          error: 'bridgeInvalidResponse',
          message: 'Bridge response payload must be a JSON object.',
        );
        return;
      }
      final responseJson = Map<String, Object?>.from(decoded);
      final rawRequestId = responseJson['requestId'];
      if (rawRequestId is! String || rawRequestId.isEmpty) {
        _completePendingWithBridgeError(
          statusCode: HttpStatus.badGateway,
          error: 'bridgeInvalidResponse',
          message:
              'Bridge response field "requestId" must be a non-empty string.',
        );
        return;
      }
      final response = CockpitRemoteBridgeResponse.fromJson(responseJson);
      final completer = _pending.remove(response.requestId);
      if (completer == null) {
        _completePendingWithBridgeError(
          statusCode: HttpStatus.badGateway,
          error: 'bridgeUnknownResponse',
          message:
              'The browser bridge returned an unknown requestId: '
              '${response.requestId}. Pending requests were failed to avoid '
              'response misattribution.',
        );
        return;
      }
      completer.complete(response);
    } on FormatException catch (error) {
      _completePendingWithBridgeError(
        statusCode: HttpStatus.badGateway,
        error: 'bridgeInvalidResponse',
        message: error.message,
      );
    } on Object catch (error) {
      _completePendingWithBridgeError(
        statusCode: HttpStatus.badGateway,
        error: 'bridgeInvalidResponse',
        message: '$error',
      );
    }
  }

  Future<CockpitRemoteSessionEndpointResponse> _resolveResponse(
    HttpRequest request,
  ) async {
    final routePath = _routePathFor(request.uri.path);
    if (routePath == null) {
      return const CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'notFound',
        'message': 'Unsupported remote session endpoint.',
      }, statusCode: HttpStatus.notFound);
    }
    if (routePath == '/recording/start' && recordingAdapter != null) {
      return _startHostRecording(request);
    }
    if (routePath == '/recording/stop' && recordingAdapter != null) {
      return _stopHostRecording();
    }
    if (routePath == '/artifacts/download') {
      final local = await _localArtifactResponse(request.uri);
      if (local != null) {
        return local;
      }
    }

    final proxied = await _forward(request);
    if (routePath == '/health' && proxied.jsonBody != null) {
      return CockpitRemoteSessionEndpointResponse.json(
        _patchedHealthBody(proxied.jsonBody!),
        statusCode: proxied.statusCode,
      );
    }
    if (routePath == '/commands/execute' && proxied.jsonBody != null) {
      return _externalizedCommandResponse(proxied);
    }
    return proxied;
  }

  Future<CockpitRemoteSessionEndpointResponse> _forward(
    HttpRequest request,
  ) async {
    final socket = _socket;
    if (socket == null) {
      return const CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'bridgeUnavailable',
        'message': 'The browser bridge is not connected.',
      }, statusCode: HttpStatus.serviceUnavailable);
    }
    final bodyText = await utf8.decoder.bind(request).join();
    Map<String, Object?>? jsonBody;
    if (bodyText.isNotEmpty) {
      final decoded = jsonDecode(bodyText);
      if (decoded is! Map<Object?, Object?>) {
        return const CockpitRemoteSessionEndpointResponse.json(
          <String, Object?>{
            'error': 'invalidPayload',
            'message': 'Request body must be a JSON object.',
          },
          statusCode: HttpStatus.badRequest,
        );
      }
      jsonBody = Map<String, Object?>.from(decoded);
    }
    final requestId =
        'bridge-${DateTime.now().toUtc().microsecondsSinceEpoch}-${_pending.length}';
    final completer = Completer<CockpitRemoteBridgeResponse>();
    _pending[requestId] = completer;
    socket.add(
      jsonEncode(
        CockpitRemoteBridgeRequest(
          requestId: requestId,
          method: request.method,
          path: request.uri.toString(),
          jsonBody: jsonBody,
        ).toJson(),
      ),
    );

    try {
      final response = await completer.future.timeout(
        _forwardTimeoutFor(request, jsonBody),
      );
      return response.jsonBody != null
          ? CockpitRemoteSessionEndpointResponse.json(
              response.jsonBody!,
              statusCode: response.statusCode,
            )
          : CockpitRemoteSessionEndpointResponse.binary(
              _binaryBodyFromBridgeResponse(response),
              statusCode: response.statusCode,
              contentType: response.contentType,
            );
    } on FormatException catch (error) {
      _pending.remove(requestId);
      return CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'bridgeInvalidResponse',
        'message': error.message,
      }, statusCode: HttpStatus.badGateway);
    } on TimeoutException {
      _pending.remove(requestId);
      return const CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'bridgeTimeout',
        'message': 'The browser bridge did not respond before timeout.',
      }, statusCode: HttpStatus.gatewayTimeout);
    }
  }

  Duration _forwardTimeoutFor(
    HttpRequest request,
    Map<String, Object?>? jsonBody,
  ) {
    if (_routePathFor(request.uri.path) != '/commands/execute') {
      return requestTimeout;
    }
    final timeout = cockpitRemoteCommandTransportTimeoutForJson(
      jsonBody,
      minimumTimeout: requestTimeout,
    );
    return timeout > requestTimeout ? timeout : requestTimeout;
  }

  List<int> _binaryBodyFromBridgeResponse(
    CockpitRemoteBridgeResponse response,
  ) {
    try {
      return response.binaryBody ?? const <int>[];
    } on FormatException catch (error) {
      throw FormatException(
        'Bridge response field "bytesBase64" must be valid base64: '
        '${error.message}',
      );
    }
  }

  Map<String, Object?> _patchedHealthBody(Map<String, Object?> body) {
    if (recordingAdapter == null) {
      return body;
    }
    final next = Map<String, Object?>.from(body);
    next['recordingCapabilities'] = CockpitRecordingCapabilities(
      supportsNativeRecording: true,
      preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
      supportedLayers: const <CockpitRecordingLayer>[
        CockpitRecordingLayer.hostScreen,
      ],
      preferredLayer: CockpitRecordingLayer.hostScreen,
      recordingLimitations: const <String>[
        'Browser recording runs on the host desktop and requires screen-capture permission for the terminal, Dart, and ffmpeg. When multiple browser windows or tabs share the same host process, window targeting remains best-effort and works most reliably with the target browser window foregrounded and isolated.',
      ],
    ).toJson();
    if (_activeRecordingSession != null) {
      next['activeRecording'] = _activeRecordingSession!.toJson();
    } else {
      next.remove('activeRecording');
    }
    return next;
  }

  Future<CockpitRemoteSessionEndpointResponse> _externalizedCommandResponse(
    CockpitRemoteSessionEndpointResponse endpointResponse,
  ) async {
    final body = endpointResponse.jsonBody!;
    if (!body.containsKey('result')) {
      return endpointResponse;
    }
    final response = CockpitRemoteCommandResponse.fromJson(body);
    if (response.artifactPayloads.isEmpty) {
      return endpointResponse;
    }
    final downloads = <CockpitRemoteArtifactDownload>[
      ...response.artifactDownloads,
    ];
    for (final payload in response.artifactPayloads) {
      final relativePath = payload.artifact.relativePath;
      if (relativePath.isEmpty) {
        continue;
      }
      if (payload.bytes.isEmpty) {
        if (_isRequiredEvidenceArtifact(payload.artifact)) {
          return CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
            'error': 'artifactPayloadEmpty',
            'message':
                'Browser command returned an empty required evidence artifact.',
            'details': <String, Object?>{
              'artifactPath': relativePath,
              'artifactRole': payload.artifact.role,
            },
          }, statusCode: HttpStatus.internalServerError);
        }
        continue;
      }
      final file = await _persistArtifactBytes(
        _sanitizeArtifactBasename(relativePath),
        payload.bytes,
      );
      _localArtifacts[relativePath] = _BridgeArtifactEntry(
        sourceFilePath: file.path,
        deleteOnClose: true,
      );
      downloads.add(
        CockpitRemoteArtifactDownload(
          artifact: payload.artifact,
          downloadPath: _downloadPathFor(relativePath),
        ),
      );
    }

    return CockpitRemoteSessionEndpointResponse.json(
      CockpitRemoteCommandResponse(
        result: response.result,
        runtimeSteps: response.runtimeSteps,
        artifactDownloads: downloads,
      ).toJson(),
      statusCode: endpointResponse.statusCode,
    );
  }

  Future<CockpitRemoteSessionEndpointResponse> _startHostRecording(
    HttpRequest request,
  ) async {
    final adapter = recordingAdapter;
    if (adapter == null) {
      return const CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'recordingUnsupported',
        'message': 'Host recording is unavailable for this bridge.',
      }, statusCode: HttpStatus.notImplemented);
    }
    final bodyText = await utf8.decoder.bind(request).join();
    final decoded = bodyText.isEmpty
        ? const <String, Object?>{}
        : Map<String, Object?>.from(
            jsonDecode(bodyText) as Map<Object?, Object?>,
          );
    final recordingRequest = CockpitRecordingRequest.fromJson(decoded);
    try {
      final session = await adapter.startRecording(recordingRequest);
      _activeRecordingSession = session;
      return CockpitRemoteSessionEndpointResponse.json(session.toJson());
    } on StateError catch (error) {
      return CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'recordingStartFailed',
        'message': error.message,
      }, statusCode: HttpStatus.preconditionFailed);
    } on Object catch (error) {
      return CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'recordingStartFailed',
        'message': '$error',
      }, statusCode: HttpStatus.internalServerError);
    }
  }

  Future<CockpitRemoteSessionEndpointResponse> _stopHostRecording() async {
    final adapter = recordingAdapter;
    if (adapter == null) {
      return const CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'recordingUnsupported',
        'message': 'Host recording is unavailable for this bridge.',
      }, statusCode: HttpStatus.notImplemented);
    }
    try {
      final result = await adapter.stopRecording();
      _activeRecordingSession = null;
      return CockpitRemoteSessionEndpointResponse.json(
        (await _hostRecordingResponseFor(result)).toJson(),
      );
    } on StateError catch (error) {
      _activeRecordingSession = null;
      return CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'recordingStopFailed',
        'message': error.message,
      }, statusCode: HttpStatus.conflict);
    } on Object catch (error) {
      _activeRecordingSession = null;
      return CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'recordingStopFailed',
        'message': '$error',
      }, statusCode: HttpStatus.internalServerError);
    }
  }

  Future<CockpitRemoteRecordingResponse> _hostRecordingResponseFor(
    CockpitRecordingResult result,
  ) async {
    final artifact = result.artifact;
    if (artifact == null) {
      return CockpitRemoteRecordingResponse(
        result: _recordingResultForTransport(result, includeArtifact: false),
      );
    }
    final artifactEntry = await _artifactEntryFor(result);
    if (artifactEntry == null) {
      return CockpitRemoteRecordingResponse(
        result: _recordingResultForTransport(result, includeArtifact: false),
      );
    }
    _localArtifacts[artifact.relativePath] = artifactEntry;
    return CockpitRemoteRecordingResponse(
      result: _recordingResultForTransport(result),
      artifactDownloads: <CockpitRemoteArtifactDownload>[
        CockpitRemoteArtifactDownload(
          artifact: artifact,
          downloadPath: _downloadPathFor(artifact.relativePath),
        ),
      ],
    );
  }

  Future<_BridgeArtifactEntry?> _artifactEntryFor(
    CockpitRecordingResult result,
  ) async {
    final bytes = result.bytes;
    if (bytes != null) {
      final file = await _persistArtifactBytes(
        _sanitizeArtifactBasename(
          result.artifact?.relativePath ?? 'recording.mp4',
        ),
        bytes,
      );
      return _BridgeArtifactEntry(
        sourceFilePath: file.path,
        deleteOnClose: true,
      );
    }
    final sourceFilePath = result.sourceFilePath;
    if (sourceFilePath == null || sourceFilePath.isEmpty) {
      return null;
    }
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      return null;
    }
    return _BridgeArtifactEntry(sourceFilePath: sourceFile.path);
  }

  Future<File> _persistArtifactBytes(String basename, List<int> bytes) async {
    final file = await _artifactTempFileFactory(basename);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  CockpitRecordingResult _recordingResultForTransport(
    CockpitRecordingResult result, {
    bool includeArtifact = true,
  }) {
    return result.copyWith(
      artifact: includeArtifact ? result.artifact : null,
      bytes: null,
      sourceFilePath: null,
    );
  }

  Future<CockpitRemoteSessionEndpointResponse?> _localArtifactResponse(
    Uri uri,
  ) async {
    final relativePath = uri.queryParameters['path'];
    if (relativePath == null || relativePath.isEmpty) {
      return null;
    }
    final entry = _localArtifacts[relativePath];
    if (entry == null) {
      return null;
    }
    final sourceFilePath = entry.sourceFilePath;
    if (sourceFilePath == null || sourceFilePath.isEmpty) {
      _localArtifacts.remove(relativePath);
      return const CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'artifactNotFound',
        'message': 'Artifact content is unavailable.',
      }, statusCode: HttpStatus.notFound);
    }
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      _localArtifacts.remove(relativePath);
      return const CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
        'error': 'artifactNotFound',
        'message': 'Artifact file is no longer available.',
      }, statusCode: HttpStatus.notFound);
    }
    return CockpitRemoteSessionEndpointResponse.binaryFile(sourceFile.path);
  }

  Future<void> _bestEffortStopActiveRecording() async {
    if (_activeRecordingSession == null) {
      return;
    }
    final adapter = recordingAdapter;
    _activeRecordingSession = null;
    if (adapter == null) {
      return;
    }
    try {
      await adapter.stopRecording();
    } on Object {
      // Cleanup is best-effort during bridge shutdown.
    }
  }

  Future<void> _deleteGeneratedArtifacts() async {
    final artifacts = _localArtifacts.values.toList(growable: false);
    _localArtifacts.clear();
    for (final artifact in artifacts) {
      if (!artifact.deleteOnClose) {
        continue;
      }
      final sourceFilePath = artifact.sourceFilePath;
      if (sourceFilePath == null || sourceFilePath.isEmpty) {
        continue;
      }
      try {
        final file = File(sourceFilePath);
        if (await file.exists()) {
          await file.delete();
        }
      } on Object {
        // Best-effort cleanup only for bridge-generated artifact files.
      }
    }
  }

  void _failPending(Object error) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  void _completePendingWithBridgeError({
    required int statusCode,
    required String error,
    required String message,
  }) {
    if (_pending.isEmpty) {
      return;
    }
    final requestIds = _pending.keys.toList(growable: false);
    final responseBody = <String, Object?>{'error': error, 'message': message};
    for (final requestId in requestIds) {
      final completer = _pending.remove(requestId);
      completer?.complete(
        CockpitRemoteBridgeResponse(
          requestId: requestId,
          statusCode: statusCode,
          jsonBody: responseBody,
        ),
      );
    }
  }

  String get _normalizedRoutePrefix {
    if (routePrefix.isEmpty || routePrefix == '/') {
      return '';
    }
    final withLeadingSlash = routePrefix.startsWith('/')
        ? routePrefix
        : '/$routePrefix';
    return withLeadingSlash.endsWith('/')
        ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
        : withLeadingSlash;
  }

  String _downloadPathFor(String relativePath) {
    return '$_normalizedRoutePrefix/artifacts/download?path=${Uri.encodeQueryComponent(relativePath)}';
  }

  String? _routePathFor(String path) {
    final prefix = _normalizedRoutePrefix;
    if (prefix.isEmpty) {
      return path;
    }
    if (path == prefix) {
      return '/';
    }
    if (path.startsWith('$prefix/')) {
      return path.substring(prefix.length);
    }
    return null;
  }

  Future<void> _writeResponse(
    HttpResponse response,
    CockpitRemoteSessionEndpointResponse endpointResponse,
  ) async {
    response.statusCode = endpointResponse.statusCode;
    if (endpointResponse.jsonBody != null) {
      response.headers.contentType = ContentType(
        'application',
        'json',
        charset: 'utf-8',
      );
      response.write(jsonEncode(_compactJsonValue(endpointResponse.jsonBody)));
    } else if (endpointResponse.sourceFilePath != null) {
      response.headers.contentType = ContentType.parse(
        endpointResponse.contentType,
      );
      await response.addStream(
        File(endpointResponse.sourceFilePath!).openRead(),
      );
    } else {
      response.headers.contentType = ContentType.parse(
        endpointResponse.contentType,
      );
      response.add(endpointResponse.binaryBody ?? const <int>[]);
    }
    await response.close();
  }
}

bool _isRequiredEvidenceArtifact(CockpitArtifactRef artifact) {
  return artifact.role == 'screenshot' || artifact.role == 'step_screenshot';
}

final class _BridgeArtifactEntry {
  const _BridgeArtifactEntry({this.sourceFilePath, this.deleteOnClose = false});

  final String? sourceFilePath;
  final bool deleteOnClose;
}

String _sanitizeArtifactBasename(String relativePath) {
  final basename = relativePath.split('/').last;
  final sanitized = basename.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return sanitized.isEmpty ? 'artifact.bin' : sanitized;
}

Future<File> _defaultBridgeArtifactTempFileFactory(String basename) async {
  return File(
    [
      Directory.systemTemp.path,
      'flutter_cockpit_bridge_${DateTime.now().toUtc().microsecondsSinceEpoch}_$basename',
    ].join(Platform.pathSeparator),
  );
}

String _joinPath(String basePath, String segment) {
  if (basePath.isEmpty || basePath == '/') {
    return '/$segment';
  }
  return '$basePath/$segment';
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
