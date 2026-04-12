import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit/flutter_cockpit_remote_bridge.dart';

import 'cockpit_browser_recording_adapter_resolver.dart';
import '../recording/cockpit_host_recording_adapter.dart';
import '../development/cockpit_development_session_handle.dart';

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
    this.requestTimeout = const Duration(seconds: 30),
  });

  final String bindHost;
  final int bindPort;
  final String routePrefix;
  final CockpitHostRecordingAdapter? recordingAdapter;
  final Duration requestTimeout;

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
    _localArtifacts.clear();
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
        CockpitRemoteSessionEndpointResponse.json(
          <String, Object?>{
            'error': 'invalidPayload',
            'message': error.message,
          },
          statusCode: HttpStatus.badRequest,
        ),
      );
    } catch (error) {
      await _writeResponse(
        request.response,
        CockpitRemoteSessionEndpointResponse.json(
          <String, Object?>{
            'error': 'serverError',
            'message': error.toString(),
          },
          statusCode: HttpStatus.internalServerError,
        ),
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
    final decoded = jsonDecode('$payload');
    if (decoded is! Map<Object?, Object?>) {
      return;
    }
    final response = CockpitRemoteBridgeResponse.fromJson(
      Map<String, Object?>.from(decoded),
    );
    final completer = _pending.remove(response.requestId);
    completer?.complete(response);
  }

  Future<CockpitRemoteSessionEndpointResponse> _resolveResponse(
    HttpRequest request,
  ) async {
    final routePath = _routePathFor(request.uri.path);
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
    return proxied;
  }

  Future<CockpitRemoteSessionEndpointResponse> _forward(
    HttpRequest request,
  ) async {
    final socket = _socket;
    if (socket == null) {
      return const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'bridgeUnavailable',
          'message': 'The browser bridge is not connected.',
        },
        statusCode: HttpStatus.serviceUnavailable,
      );
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
      final response = await completer.future.timeout(requestTimeout);
      return response.jsonBody != null
          ? CockpitRemoteSessionEndpointResponse.json(
              response.jsonBody!,
              statusCode: response.statusCode,
            )
          : CockpitRemoteSessionEndpointResponse.binary(
              response.binaryBody ?? const <int>[],
              statusCode: response.statusCode,
              contentType: response.contentType,
            );
    } on TimeoutException {
      _pending.remove(requestId);
      return const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'bridgeTimeout',
          'message': 'The browser bridge did not respond before timeout.',
        },
        statusCode: HttpStatus.gatewayTimeout,
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
      recordingLimitations: const <String>[
        'Browser recording runs on the host desktop and requires screen-capture permission for the terminal, Dart, and ffmpeg.',
      ],
    ).toJson();
    if (_activeRecordingSession != null) {
      next['activeRecording'] = _activeRecordingSession!.toJson();
    } else {
      next.remove('activeRecording');
    }
    return next;
  }

  Future<CockpitRemoteSessionEndpointResponse> _startHostRecording(
    HttpRequest request,
  ) async {
    final adapter = recordingAdapter;
    if (adapter == null) {
      return const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'recordingUnsupported',
          'message': 'Host recording is unavailable for this bridge.',
        },
        statusCode: HttpStatus.notImplemented,
      );
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
      return CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'recordingStartFailed',
          'message': error.message,
        },
        statusCode: HttpStatus.preconditionFailed,
      );
    } on Object catch (error) {
      return CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'recordingStartFailed',
          'message': '$error',
        },
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  Future<CockpitRemoteSessionEndpointResponse> _stopHostRecording() async {
    final adapter = recordingAdapter;
    if (adapter == null) {
      return const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'recordingUnsupported',
          'message': 'Host recording is unavailable for this bridge.',
        },
        statusCode: HttpStatus.notImplemented,
      );
    }
    try {
      final result = await adapter.stopRecording();
      _activeRecordingSession = null;
      return CockpitRemoteSessionEndpointResponse.json(
        _hostRecordingResponseFor(result).toJson(),
      );
    } on StateError catch (error) {
      _activeRecordingSession = null;
      return CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'recordingStopFailed',
          'message': error.message,
        },
        statusCode: HttpStatus.conflict,
      );
    } on Object catch (error) {
      _activeRecordingSession = null;
      return CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'recordingStopFailed',
          'message': '$error',
        },
        statusCode: HttpStatus.internalServerError,
      );
    }
  }

  CockpitRemoteRecordingResponse _hostRecordingResponseFor(
    CockpitRecordingResult result,
  ) {
    final artifact = result.artifact;
    final artifactEntry = _artifactEntryFor(result);
    if (artifact == null || artifactEntry == null) {
      return CockpitRemoteRecordingResponse(result: result);
    }
    _localArtifacts[artifact.relativePath] = artifactEntry;
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

  _BridgeArtifactEntry? _artifactEntryFor(CockpitRecordingResult result) {
    final bytes = result.bytes;
    if (bytes != null) {
      return _BridgeArtifactEntry(bytes: List<int>.unmodifiable(bytes));
    }
    final sourceFilePath = result.sourceFilePath;
    if (sourceFilePath == null || sourceFilePath.isEmpty) {
      return null;
    }
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      return null;
    }
    return _BridgeArtifactEntry(
      sourceFilePath: sourceFile.path,
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
    final bytes = entry.bytes;
    if (bytes != null) {
      return CockpitRemoteSessionEndpointResponse.binary(bytes);
    }
    final sourceFilePath = entry.sourceFilePath;
    if (sourceFilePath == null || sourceFilePath.isEmpty) {
      _localArtifacts.remove(relativePath);
      return const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'artifactNotFound',
          'message': 'Artifact content is unavailable.',
        },
        statusCode: HttpStatus.notFound,
      );
    }
    final sourceFile = File(sourceFilePath);
    if (!sourceFile.existsSync()) {
      _localArtifacts.remove(relativePath);
      return const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{
          'error': 'artifactNotFound',
          'message': 'Artifact file is no longer available.',
        },
        statusCode: HttpStatus.notFound,
      );
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

  void _failPending(Object error) {
    final pending = _pending.values.toList(growable: false);
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
  }

  String get _normalizedRoutePrefix {
    if (routePrefix.isEmpty || routePrefix == '/') {
      return '';
    }
    final withLeadingSlash =
        routePrefix.startsWith('/') ? routePrefix : '/$routePrefix';
    return withLeadingSlash.endsWith('/')
        ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
        : withLeadingSlash;
  }

  String _routePathFor(String path) {
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
    return path;
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

final class _BridgeArtifactEntry {
  const _BridgeArtifactEntry({this.bytes, this.sourceFilePath});

  final List<int>? bytes;
  final String? sourceFilePath;
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
