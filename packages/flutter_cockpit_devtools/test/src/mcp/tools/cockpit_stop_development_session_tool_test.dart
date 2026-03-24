import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_stop_development_session_tool.dart';
import 'package:test/test.dart';

void main() {
  test('stop development tool returns stopped status', () async {
    CockpitStopDevelopmentSessionRequest? capturedRequest;
    final tool = CockpitStopDevelopmentSessionTool(
      stop: (request) async {
        capturedRequest = request;
        return CockpitStopDevelopmentSessionResult(
          sessionHandle: _handle(),
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'dev-session-1',
            state: CockpitDevelopmentSessionState.stopped,
            appReachable: false,
            remoteSessionReachable: false,
            reloadGeneration: 4,
            lastStatusAt: DateTime.utc(2026, 3, 23),
          ),
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'session_handle_path': '/tmp/dev-session.json',
    });

    expect(capturedRequest?.sessionHandlePath, '/tmp/dev-session.json');
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect((structured['status'] as Map<String, Object?>)['state'], 'stopped');
  });
}

CockpitDevelopmentSessionHandle _handle() => CockpitDevelopmentSessionHandle(
      developmentSessionId: 'dev-session-1',
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'lib/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      appBaseUrl: 'http://127.0.0.1:57331',
      supervisorBaseUrl: 'http://127.0.0.1:59331',
      remoteSessionHandle: CockpitRemoteSessionHandle(
        platform: 'android',
        deviceId: 'emulator-5554',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: 57331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:57331',
        launchedAt: DateTime.utc(2026, 3, 23),
      ),
      launchedAt: DateTime.utc(2026, 3, 23),
      reloadGeneration: 4,
    );
