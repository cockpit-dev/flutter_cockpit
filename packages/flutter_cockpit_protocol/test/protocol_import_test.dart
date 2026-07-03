import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_remote_bridge_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('core protocol models serialize without Flutter SDK dependencies', () {
    final command = CockpitCommand(
      commandId: 'tap-settings',
      commandType: CockpitCommandType.tap,
      locator: const CockpitLocator(text: 'Settings'),
    );

    expect(command.toJson()['commandType'], 'tap');
    expect(command.toJson()['locator'], isA<Map<String, Object?>>());
  });

  test('bridge protocol DTOs remain JSON-only', () {
    final request = CockpitRemoteBridgeRequest.fromJson(<String, Object?>{
      'requestId': 'request-1',
      'method': 'GET',
      'path': '/health',
    });
    final response = CockpitRemoteBridgeResponse.fromEndpointResponse(
      requestId: request.requestId,
      response: const CockpitRemoteSessionEndpointResponse.json(
        <String, Object?>{'ok': true},
      ),
    );

    expect(request.uri.path, '/health');
    expect(response.toJson()['jsonBody'], <String, Object?>{'ok': true});
  });
}
