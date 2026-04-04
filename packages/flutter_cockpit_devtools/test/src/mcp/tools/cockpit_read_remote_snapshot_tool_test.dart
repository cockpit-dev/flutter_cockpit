import 'package:flutter_cockpit_devtools/src/application/cockpit_read_remote_snapshot_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_remote_snapshot_tool.dart';
import 'package:test/test.dart';

void main() {
  test('read_remote_snapshot parses snapshot options and compare refs',
      () async {
    CockpitReadRemoteSnapshotRequest? capturedRequest;
    final tool = CockpitReadRemoteSnapshotTool(
      read: (request) async {
        capturedRequest = request;
        return const CockpitReadRemoteSnapshotResult(
          routeName: '/details',
          diagnosticLevel: 'baseline',
          truncated: false,
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'sessionHandle': <String, Object?>{
        'platform': 'macos',
        'deviceId': 'macos',
        'projectDir': '/workspace',
        'target': 'cockpit/main.dart',
        'appId': 'dev.cockpit.demo',
        'host': '127.0.0.1',
        'hostPort': 47331,
        'devicePort': 47331,
        'baseUrl': 'http://127.0.0.1:47331',
        'launchedAt': '2026-03-30T00:00:00.000Z',
      },
      'profile': 'inspect',
      'snapshotOptions': <String, Object?>{'profile': 'forensic'},
      'compareAgainstSnapshotRef': 'snapshot-1',
    });

    expect(capturedRequest?.resultProfile.name.jsonValue, 'inspect');
    expect(capturedRequest?.snapshotOptions?.profile.jsonValue, 'forensic');
    expect(capturedRequest?.compareAgainstSnapshotRef, 'snapshot-1');
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
