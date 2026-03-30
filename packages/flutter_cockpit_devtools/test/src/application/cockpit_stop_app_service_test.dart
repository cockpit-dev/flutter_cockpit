import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  test('stop app stops development apps through the development stop path',
      () async {
    final handle = CockpitDevelopmentSessionHandle(
      developmentSessionId: 'dev-session-1',
      platform: 'macos',
      deviceId: 'macos',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      appId: 'dev.cockpit.demo',
      appBaseUrl: 'http://127.0.0.1:57331',
      supervisorBaseUrl: 'http://127.0.0.1:59331',
      launchedAt: DateTime.utc(2026, 3, 30),
      reloadGeneration: 0,
    );
    final app = CockpitAppHandle.fromDevelopmentSession(handle);
    CockpitStopDevelopmentSessionRequest? capturedRequest;

    final service = CockpitStopAppService(
      stopDevelopment: (request) async {
        capturedRequest = request;
        return CockpitStopDevelopmentSessionResult(
          sessionHandle: handle,
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: handle.developmentSessionId,
            state: CockpitDevelopmentSessionState.stopped,
            appReachable: false,
            remoteSessionReachable: false,
            reloadGeneration: handle.reloadGeneration,
            lastStatusAt: DateTime.utc(2026, 3, 30, 0, 1),
          ),
        );
      },
    );

    final result = await service.stop(CockpitStopAppRequest(app: app));

    expect(
        capturedRequest?.sessionHandle?.developmentSessionId, 'dev-session-1');
    expect(result.status.mode, CockpitAppMode.development);
    expect(result.status.state, 'stopped');
    expect(result.status.appReachable, isFalse);
  });

  test('stop app stops automation apps through the automation stop path',
      () async {
    final app = CockpitAppHandle(
      appId: 'dev.cockpit.demo',
      mode: CockpitAppMode.automation,
      platform: 'macos',
      deviceId: 'macos',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      baseUrl: 'http://127.0.0.1:57331',
      launchedAt: DateTime.utc(2026, 3, 30),
      platformAppId: 'dev.cockpit.demo',
    );
    CockpitAppHandle? stoppedApp;
    var probeCalls = 0;

    final service = CockpitStopAppService(
      stopAutomation: (resolvedApp) async {
        stoppedApp = resolvedApp;
      },
      probeReachability: (_) async {
        probeCalls += 1;
        return false;
      },
    );

    final result = await service.stop(CockpitStopAppRequest(app: app));

    expect(stoppedApp?.appId, 'dev.cockpit.demo');
    expect(probeCalls, greaterThanOrEqualTo(1));
    expect(result.status.mode, CockpitAppMode.automation);
    expect(result.status.state, 'stopped');
    expect(result.status.remoteSessionReachable, isFalse);
  });
}
