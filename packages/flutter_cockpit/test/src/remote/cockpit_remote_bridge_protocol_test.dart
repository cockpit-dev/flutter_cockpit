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
          return CockpitRemoteSessionEndpointResponse.json(
            <String, Object?>{'error': 'not_found'},
            statusCode: 404,
          );
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
}
