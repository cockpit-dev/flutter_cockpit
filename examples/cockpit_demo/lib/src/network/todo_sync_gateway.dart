import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/todo_sync_conflict.dart';
import 'todo_sync_contract.dart';

abstract interface class TodoSyncGatewayClient {
  Future<TodoSyncProbeResult> probeHealth();

  Future<TodoSyncBatchResult> syncTasks(TodoSyncBatchRequest request);

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
typedef TodoSyncBatchHandler = Future<TodoSyncBatchResult> Function(
  TodoSyncBatchRequest request,
);

final class TodoLoopbackSyncGateway implements TodoSyncGatewayClient {
  TodoLoopbackSyncGateway({
    required TodoSyncPayloadBuilder payloadBuilder,
    HttpClient Function()? httpClientFactory,
    TodoSyncFailurePredicate? shouldSimulateFailure,
    TodoSyncBatchHandler? batchHandler,
    String host = '127.0.0.1',
  })  : _payloadBuilder = payloadBuilder,
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _shouldSimulateFailure = shouldSimulateFailure,
        _batchHandler = batchHandler,
        _host = host;

  final TodoSyncPayloadBuilder _payloadBuilder;
  final HttpClient Function() _httpClientFactory;
  final TodoSyncFailurePredicate? _shouldSimulateFailure;
  final TodoSyncBatchHandler? _batchHandler;
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
  Future<TodoSyncBatchResult> syncTasks(TodoSyncBatchRequest request) async {
    final batchHandler = _batchHandler;
    if (batchHandler != null) {
      return batchHandler(request);
    }

    if (_shouldSimulateFailure?.call() ?? false) {
      return TodoSyncBatchResult(
        retryableFailures: request.tasks
            .map(
              (task) => TodoSyncRetryableFailure(
                taskId: task.id,
                summary:
                    'Simulated relay outage · retry after disabling diagnostics failure mode.',
              ),
            )
            .toList(growable: false),
      );
    }

    final succeededTaskIds = <String>[];
    final retryableFailures = <TodoSyncRetryableFailure>[];
    final conflicts = <TodoSyncConflictEntry>[];

    for (final task in request.tasks) {
      final normalizedTitle = task.title.toLowerCase();
      if (task.pendingChanges.contains('resolved_keep_local')) {
        succeededTaskIds.add(task.id);
        continue;
      }
      if (task.pendingChanges.contains('simulate_conflict') ||
          normalizedTitle.contains('conflict')) {
        conflicts.add(
          TodoSyncConflictEntry(
            taskId: task.id,
            conflict: const TodoSyncConflict(
              type: TodoSyncConflictType.concurrentEdit,
              summary: 'Remote notes changed while local title changed.',
              localFields: <String>['title'],
              remoteFields: <String>['notes'],
            ),
          ),
        );
        continue;
      }
      if (task.pendingChanges.contains('simulate_retry') ||
          normalizedTitle.contains('retry')) {
        retryableFailures.add(
          TodoSyncRetryableFailure(
            taskId: task.id,
            summary: 'Relay timed out while syncing ${task.title}.',
          ),
        );
        continue;
      }
      succeededTaskIds.add(task.id);
    }

    return TodoSyncBatchResult(
      succeededTaskIds: succeededTaskIds,
      retryableFailures: retryableFailures,
      conflicts: conflicts,
    );
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
