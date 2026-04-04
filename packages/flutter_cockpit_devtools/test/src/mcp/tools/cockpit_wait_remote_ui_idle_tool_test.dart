import 'package:flutter_cockpit_devtools/src/application/cockpit_wait_remote_ui_idle_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_wait_remote_ui_idle_tool.dart';
import 'package:test/test.dart';

void main() {
  test('wait_remote_ui_idle parses timing arguments', () async {
    CockpitWaitRemoteUiIdleRequest? capturedRequest;
    final tool = CockpitWaitRemoteUiIdleTool(
      wait: (request) async {
        capturedRequest = request;
        return const CockpitWaitRemoteUiIdleResult(
          idle: true,
          durationMs: 10,
          quietWindowMs: 120,
          timeoutMs: 2000,
          includeNetworkIdle: false,
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
      'quietWindowMs': 120,
      'timeoutMs': 2000,
      'includeNetworkIdle': false,
    });

    expect(capturedRequest?.quietWindow.inMilliseconds, 120);
    expect(capturedRequest?.timeout.inMilliseconds, 2000);
    expect(capturedRequest?.includeNetworkIdle, isFalse);
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
