import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_reload_development_session_tool.dart';
import 'package:test/test.dart';

void main() {
  test('reload development tool supports hot_restart', () async {
    CockpitReloadDevelopmentSessionRequest? capturedRequest;
    final tool = CockpitReloadDevelopmentSessionTool(
      reload: (request) async {
        capturedRequest = request;
        return CockpitReloadDevelopmentSessionResult(
          sessionHandle: _handle(),
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'dev-session-1',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 4,
            lastReloadMode: CockpitDevelopmentReloadMode.hotRestart,
            lastStatusAt: DateTime.utc(2026, 3, 23),
          ),
          persistedHandlePath: '/tmp/dev-session.json',
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'session_handle': _handle().toJson(),
      'mode': 'hot_restart',
    });

    expect(capturedRequest?.mode, CockpitDevelopmentReloadMode.hotRestart);
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(
      (structured['status'] as Map<String, Object?>)['lastReloadMode'],
      'hot_restart',
    );
  });
}

CockpitDevelopmentSessionHandle _handle() => CockpitDevelopmentSessionHandle(
      developmentSessionId: 'dev-session-1',
      platform: 'ios',
      deviceId: 'simulator',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'lib/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      appBaseUrl: 'http://127.0.0.1:58421',
      supervisorBaseUrl: 'http://127.0.0.1:59421',
      remoteSessionHandle: CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: 'simulator',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: 58421,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:58421',
        launchedAt: DateTime.utc(2026, 3, 23),
      ),
      launchedAt: DateTime.utc(2026, 3, 23),
      reloadGeneration: 3,
    );
