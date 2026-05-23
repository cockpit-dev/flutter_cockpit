import 'dart:convert';

import 'package:flutter_cockpit/src/remote/cockpit_remote_bridge_protocol.dart';
import 'package:flutter_cockpit/src/remote/cockpit_remote_session_endpoint_handler.dart';
import 'package:test/test.dart';

void main() {
  test(
    'bridge protocol returns JSON and binary endpoint responses over one message format',
    () async {
      final protocol = CockpitRemoteSessionBridgeProtocol(
        requestHandler: (request) async {
          switch (request.uri.path) {
            case '/health':
              return CockpitRemoteSessionEndpointResponse.json(
                <String, Object?>{
                  'sessionId': 'bridge-session',
                  'state': 'ready',
                },
              );
            case '/artifacts/download':
              return CockpitRemoteSessionEndpointResponse.binary(
                utf8.encode('artifact-bytes'),
              );
          }
          return CockpitRemoteSessionEndpointResponse.json(<String, Object?>{
            'error': 'not_found',
          }, statusCode: 404);
        },
      );

      final healthResponseText = await protocol.handleRawMessage(
        jsonEncode(
          const CockpitRemoteBridgeRequest(
            requestId: 'req-health',
            method: 'GET',
            path: '/health',
          ).toJson(),
        ),
      );
      final healthResponse = CockpitRemoteBridgeResponse.fromJson(
        Map<String, Object?>.from(
          jsonDecode(healthResponseText) as Map<Object?, Object?>,
        ),
      );

      expect(healthResponse.requestId, 'req-health');
      expect(healthResponse.statusCode, 200);
      expect(healthResponse.jsonBody?['sessionId'], 'bridge-session');
      expect(healthResponse.bytesBase64, isNull);

      final artifactResponseText = await protocol.handleRawMessage(
        jsonEncode(
          const CockpitRemoteBridgeRequest(
            requestId: 'req-artifact',
            method: 'GET',
            path: '/artifacts/download?path=recordings%2Facceptance.mp4',
          ).toJson(),
        ),
      );
      final artifactResponse = CockpitRemoteBridgeResponse.fromJson(
        Map<String, Object?>.from(
          jsonDecode(artifactResponseText) as Map<Object?, Object?>,
        ),
      );

      expect(artifactResponse.requestId, 'req-artifact');
      expect(artifactResponse.statusCode, 200);
      expect(
        utf8.decode(base64Decode(artifactResponse.bytesBase64!)),
        'artifact-bytes',
      );
      expect(artifactResponse.jsonBody, isNull);
    },
  );

  test(
    'bridge protocol serializes file-backed binary responses when a reader is provided',
    () async {
      final protocol = CockpitRemoteSessionBridgeProtocol(
        requestHandler: (request) async {
          return const CockpitRemoteSessionEndpointResponse.binaryFile(
            '/tmp/flutter_cockpit_bridge_artifact.mp4',
            contentType: 'video/mp4',
          );
        },
        binaryFileReader: (sourceFilePath) {
          expect(sourceFilePath, '/tmp/flutter_cockpit_bridge_artifact.mp4');
          return utf8.encode('file-backed-artifact');
        },
      );

      final responseText = await protocol.handleRawMessage(
        jsonEncode(
          const CockpitRemoteBridgeRequest(
            requestId: 'req-file-artifact',
            method: 'GET',
            path: '/artifacts/download?path=recordings%2Facceptance.mp4',
          ).toJson(),
        ),
      );
      final response = CockpitRemoteBridgeResponse.fromJson(
        Map<String, Object?>.from(
          jsonDecode(responseText) as Map<Object?, Object?>,
        ),
      );

      expect(response.requestId, 'req-file-artifact');
      expect(response.statusCode, 200);
      expect(response.contentType, 'video/mp4');
      expect(
        utf8.decode(base64Decode(response.bytesBase64!)),
        'file-backed-artifact',
      );
      expect(response.jsonBody, isNull);
    },
  );

  test(
    'bridge protocol reports a structured error for file-backed responses without a reader',
    () async {
      final protocol = CockpitRemoteSessionBridgeProtocol(
        requestHandler: (request) async {
          return const CockpitRemoteSessionEndpointResponse.binaryFile(
            '/tmp/flutter_cockpit_bridge_artifact.mp4',
          );
        },
      );

      final responseText = await protocol.handleRawMessage(
        jsonEncode(
          const CockpitRemoteBridgeRequest(
            requestId: 'req-missing-reader',
            method: 'GET',
            path: '/artifacts/download?path=recordings%2Facceptance.mp4',
          ).toJson(),
        ),
      );
      final response = CockpitRemoteBridgeResponse.fromJson(
        Map<String, Object?>.from(
          jsonDecode(responseText) as Map<Object?, Object?>,
        ),
      );

      expect(response.requestId, 'req-missing-reader');
      expect(response.statusCode, 500);
      expect(response.jsonBody?['error'], 'bridgeBinaryFileUnsupported');
      expect(response.bytesBase64, isNull);
    },
  );

  test(
    'bridge protocol returns structured errors instead of leaking failures',
    () async {
      final handlerFailureProtocol = CockpitRemoteSessionBridgeProtocol(
        requestHandler: (_) async {
          throw StateError('executor crashed');
        },
      );

      final handlerFailureText = await handlerFailureProtocol.handleRawMessage(
        jsonEncode(
          const CockpitRemoteBridgeRequest(
            requestId: 'req-handler-failure',
            method: 'GET',
            path: '/health',
          ).toJson(),
        ),
      );
      final handlerFailure = CockpitRemoteBridgeResponse.fromJson(
        Map<String, Object?>.from(
          jsonDecode(handlerFailureText) as Map<Object?, Object?>,
        ),
      );
      expect(handlerFailure.requestId, 'req-handler-failure');
      expect(handlerFailure.statusCode, 500);
      expect(handlerFailure.jsonBody?['error'], 'bridgeRequestFailed');
      expect(handlerFailure.jsonBody?['message'], contains('executor crashed'));

      final fileFailureProtocol = CockpitRemoteSessionBridgeProtocol(
        requestHandler: (_) async {
          return const CockpitRemoteSessionEndpointResponse.binaryFile(
            '/missing/artifact.mp4',
          );
        },
        binaryFileReader: (_) {
          throw StateError('file disappeared');
        },
      );

      final fileFailureText = await fileFailureProtocol.handleRawMessage(
        jsonEncode(
          const CockpitRemoteBridgeRequest(
            requestId: 'req-file-failure',
            method: 'GET',
            path: '/artifacts/download?path=recordings%2Facceptance.mp4',
          ).toJson(),
        ),
      );
      final fileFailure = CockpitRemoteBridgeResponse.fromJson(
        Map<String, Object?>.from(
          jsonDecode(fileFailureText) as Map<Object?, Object?>,
        ),
      );
      expect(fileFailure.requestId, 'req-file-failure');
      expect(fileFailure.statusCode, 500);
      expect(fileFailure.jsonBody?['error'], 'bridgeBinaryFileReadFailed');
      expect(fileFailure.jsonBody?['message'], contains('file disappeared'));

      final invalidMessageText = await handlerFailureProtocol.handleRawMessage(
        jsonEncode(const <Object?>['not', 'a', 'request']),
      );
      final invalidMessage = CockpitRemoteBridgeResponse.fromJson(
        Map<String, Object?>.from(
          jsonDecode(invalidMessageText) as Map<Object?, Object?>,
        ),
      );
      expect(invalidMessage.requestId, 'unknown');
      expect(invalidMessage.statusCode, 400);
      expect(invalidMessage.jsonBody?['error'], 'bridgeInvalidMessage');

      final malformedRequestText = await handlerFailureProtocol
          .handleRawMessage(
            jsonEncode(const <String, Object?>{
              'requestId': 'req-malformed',
              'method': 'GET',
            }),
          );
      final malformedRequest = CockpitRemoteBridgeResponse.fromJson(
        Map<String, Object?>.from(
          jsonDecode(malformedRequestText) as Map<Object?, Object?>,
        ),
      );
      expect(malformedRequest.requestId, 'req-malformed');
      expect(malformedRequest.statusCode, 400);
      expect(malformedRequest.jsonBody?['error'], 'bridgeInvalidMessage');
      expect(
        malformedRequest.jsonBody?['message'],
        contains('"path" must be a non-empty string'),
      );
    },
  );

  test('bridge response parser rejects malformed response fields', () {
    expect(
      () => CockpitRemoteBridgeResponse.fromJson(const <String, Object?>{
        'requestId': 'req-bad-status',
        'statusCode': '200',
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('"statusCode" must be an integer'),
        ),
      ),
    );

    expect(
      () => CockpitRemoteBridgeResponse.fromJson(const <String, Object?>{
        'requestId': 'req-bad-status-range',
        'statusCode': 700,
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('"statusCode" must be an HTTP status code'),
        ),
      ),
    );

    expect(
      () => CockpitRemoteBridgeResponse.fromJson(const <String, Object?>{
        'requestId': 'req-bad-body',
        'statusCode': 200,
        'jsonBody': <Object?>['not', 'an', 'object'],
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('"jsonBody" must be a JSON object'),
        ),
      ),
    );

    expect(
      () => CockpitRemoteBridgeResponse.fromJson(const <String, Object?>{
        'requestId': 'req-ambiguous-body',
        'statusCode': 200,
        'jsonBody': <String, Object?>{'ok': true},
        'bytesBase64': 'AQID',
      }),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('must not contain both "jsonBody" and "bytesBase64"'),
        ),
      ),
    );
  });
}
