import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'cockpit_development_session_handle.dart';
import 'cockpit_development_session_status.dart';

final class CockpitDevelopmentSessionSupervisorResponse {
  const CockpitDevelopmentSessionSupervisorResponse({
    required this.status,
    required this.sessionHandle,
  });

  final CockpitDevelopmentSessionStatus status;
  final CockpitDevelopmentSessionHandle sessionHandle;
}

final class CockpitDevelopmentSessionSupervisorClient {
  CockpitDevelopmentSessionSupervisorClient({
    HttpClient Function()? httpClientFactory,
    Duration? requestTimeout,
  })  : _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _requestTimeout = requestTimeout ?? const Duration(seconds: 90);

  final HttpClient Function() _httpClientFactory;
  final Duration _requestTimeout;

  Future<CockpitDevelopmentSessionStatus> readHealth(
    Uri supervisorBaseUri,
  ) async {
    final payload = await _send(
      supervisorBaseUri: supervisorBaseUri,
      method: 'GET',
      path: '/health',
    );
    return CockpitDevelopmentSessionStatus.fromJson(payload);
  }

  Future<CockpitDevelopmentSessionSupervisorResponse> readStatus(
    Uri supervisorBaseUri,
  ) async {
    final payload = await _send(
      supervisorBaseUri: supervisorBaseUri,
      method: 'GET',
      path: '/status',
    );
    return _parseSupervisorResponse(payload);
  }

  Future<CockpitDevelopmentSessionSupervisorResponse> reload(
    Uri supervisorBaseUri,
    CockpitDevelopmentReloadMode mode,
  ) async {
    final payload = await _send(
      supervisorBaseUri: supervisorBaseUri,
      method: 'POST',
      path: '/reload',
      body: <String, Object?>{'mode': mode.jsonValue},
    );
    return _parseSupervisorResponse(payload);
  }

  Future<CockpitDevelopmentSessionSupervisorResponse> stop(
    Uri supervisorBaseUri,
  ) async {
    final payload = await _send(
      supervisorBaseUri: supervisorBaseUri,
      method: 'POST',
      path: '/stop',
      body: const <String, Object?>{},
    );
    return _parseSupervisorResponse(payload);
  }

  Future<Map<String, Object?>> _send({
    required Uri supervisorBaseUri,
    required String method,
    required String path,
    Map<String, Object?>? body,
  }) async {
    final client = _httpClientFactory();
    try {
      return await (() async {
        final request = await client.openUrl(
          method,
          supervisorBaseUri.resolve(path),
        );
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        final payload = await utf8.decoder.bind(response).join();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw StateError(
            'Development supervisor request failed: ${response.statusCode} $payload',
          );
        }
        final decoded = jsonDecode(payload);
        if (decoded is! Map<Object?, Object?>) {
          throw StateError(
            'Development supervisor response must be a JSON object.',
          );
        }
        return Map<String, Object?>.from(decoded);
      })()
          .timeout(
        _requestTimeout,
        onTimeout: () {
          client.close(force: true);
          throw TimeoutException(
            'Development supervisor request timed out for $method $path.',
          );
        },
      );
    } finally {
      client.close(force: true);
    }
  }

  CockpitDevelopmentSessionSupervisorResponse _parseSupervisorResponse(
    Map<String, Object?> payload,
  ) {
    return CockpitDevelopmentSessionSupervisorResponse(
      status: CockpitDevelopmentSessionStatus.fromJson(
        Map<String, Object?>.from(payload['status']! as Map<Object?, Object?>),
      ),
      sessionHandle: CockpitDevelopmentSessionHandle.fromJson(
        Map<String, Object?>.from(payload['handle']! as Map<Object?, Object?>),
      ),
    );
  }
}
