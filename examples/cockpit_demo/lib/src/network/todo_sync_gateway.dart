import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

abstract interface class TodoSyncGatewayClient {
  Future<TodoSyncProbeResult> probeHealth();

  Future<void> close();
}

@immutable
final class TodoSyncProbeResult {
  const TodoSyncProbeResult({
    required this.endpoint,
    required this.checkedAt,
    required this.statusCode,
    required this.responseBody,
    required this.summary,
  });

  final Uri endpoint;
  final DateTime checkedAt;
  final int statusCode;
  final Map<String, Object?> responseBody;
  final String summary;
}

typedef TodoSyncPayloadBuilder = Future<Map<String, Object?>> Function();
typedef TodoSyncFailurePredicate = bool Function();

final class TodoLoopbackSyncGateway implements TodoSyncGatewayClient {
  TodoLoopbackSyncGateway({
    required TodoSyncPayloadBuilder payloadBuilder,
    HttpClient Function()? httpClientFactory,
    TodoSyncFailurePredicate? shouldSimulateFailure,
    String host = '127.0.0.1',
  })  : _payloadBuilder = payloadBuilder,
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _shouldSimulateFailure = shouldSimulateFailure,
        _host = host;

  final TodoSyncPayloadBuilder _payloadBuilder;
  final HttpClient Function() _httpClientFactory;
  final TodoSyncFailurePredicate? _shouldSimulateFailure;
  final String _host;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  Uri? _baseUri;

  @override
  Future<TodoSyncProbeResult> probeHealth() async {
    final endpoint = (await _ensureServer()).resolve('/sync/health');
    final client = _httpClientFactory();
    try {
      final request = await client.getUrl(endpoint);
      final response = await request.close();
      final payload = await utf8.decoder.bind(response).join();
      final json = payload.isEmpty
          ? const <String, Object?>{}
          : Map<String, Object?>.from(
              jsonDecode(payload) as Map<Object?, Object?>,
            );
      final summary = (json['summary'] as String?) ??
          'Relay responded with HTTP ${response.statusCode}.';
      return TodoSyncProbeResult(
        endpoint: endpoint,
        checkedAt: DateTime.now().toUtc(),
        statusCode: response.statusCode,
        responseBody: json,
        summary: summary,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await _server?.close(force: true);
    _subscription = null;
    _server = null;
    _baseUri = null;
  }

  Future<Uri> _ensureServer() async {
    final existing = _baseUri;
    if (existing != null) {
      return existing;
    }

    final server = await HttpServer.bind(_host, 0);
    _server = server;
    _baseUri = Uri(scheme: 'http', host: _host, port: server.port);
    _subscription = server.listen(_handleRequest);
    return _baseUri!;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method != 'GET' || request.uri.path != '/sync/health') {
      request.response.statusCode = HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'status': 'not_found',
          'summary': 'Unknown sync relay route.',
        }),
      );
      await request.response.close();
      return;
    }

    if (_shouldSimulateFailure?.call() ?? false) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(<String, Object?>{
          'status': 'degraded',
          'summary':
              'Simulated relay outage · retry after disabling diagnostics failure mode.',
        }),
      );
      await request.response.close();
      return;
    }

    final payload = await _payloadBuilder();
    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }
}
