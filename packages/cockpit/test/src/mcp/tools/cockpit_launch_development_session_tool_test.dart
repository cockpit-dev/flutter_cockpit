import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/mcp/tools/cockpit_launch_development_session_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'launch development tool exposes required inputs and returns status',
    () async {
      CockpitLaunchDevelopmentSessionRequest? capturedRequest;
      final tool = CockpitLaunchDevelopmentSessionTool(
        launch: (request) async {
          capturedRequest = request;
          return CockpitLaunchDevelopmentSessionResult(
            sessionHandle: _handle(),
            status: _status(CockpitDevelopmentSessionState.ready),
            persistedHandlePath: '/tmp/dev-session.json',
          );
        },
      );

      expect(tool.inputSchema['required'], contains('projectDir'));

      final result = await tool.call(<String, Object?>{
        'projectDir': '/workspace/examples/cockpit_demo',
        'target': 'lib/main.dart',
        'platform': 'android',
        'deviceId': 'emulator-5554',
        'sessionPort': 47331,
        'persistAppHandlePath': '/tmp/latest_app.json',
      });

      expect(capturedRequest?.platform, 'android');
      expect(capturedRequest?.persistAppHandlePath, '/tmp/latest_app.json');
      final structured = result['structuredContent'] as Map<String, Object?>;
      expect((structured['status'] as Map<String, Object?>)['state'], 'ready');
      expect(
        (structured['app'] as Map<String, Object?>)['mode'],
        'development',
      );
    },
  );

  test('launch development tool maps service errors into MCP errors', () async {
    final tool = CockpitLaunchDevelopmentSessionTool(
      launch: (_) async => throw const CockpitApplicationServiceException(
        code: 'launchFailed',
        message: 'Launch failed.',
      ),
    );

    expect(
      () => tool.call(<String, Object?>{
        'projectDir': '/workspace/examples/cockpit_demo',
        'target': 'lib/main.dart',
        'platform': 'android',
        'deviceId': 'emulator-5554',
        'sessionPort': 47331,
      }),
      throwsA(isA<CockpitMcpError>()),
    );
  });

  test('launch development tool accepts macos arguments', () async {
    CockpitLaunchDevelopmentSessionRequest? capturedRequest;
    final tool = CockpitLaunchDevelopmentSessionTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchDevelopmentSessionResult(
          sessionHandle: CockpitDevelopmentSessionHandle(
            developmentSessionId: 'dev-session-macos',
            platform: 'macos',
            deviceId: 'macos',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            appId: 'dev.cockpit.cockpit_demo',
            appBaseUrl: 'http://127.0.0.1:57331',
            supervisorBaseUrl: 'http://127.0.0.1:59331',
            remoteSessionHandle: CockpitRemoteSessionHandle(
              platform: 'macos',
              deviceId: 'macos',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              appId: 'dev.cockpit.cockpit_demo',
              host: '127.0.0.1',
              hostPort: 57331,
              devicePort: 47331,
              baseUrl: 'http://127.0.0.1:57331',
              launchedAt: DateTime.utc(2026, 3, 23),
            ),
            launchedAt: DateTime.utc(2026, 3, 23),
            reloadGeneration: 0,
          ),
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'dev-session-macos',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 0,
            lastStatusAt: DateTime.utc(2026, 3, 23),
          ),
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'projectDir': '/workspace/examples/cockpit_demo',
      'target': 'cockpit/main.dart',
      'platform': 'macos',
      'deviceId': 'macos',
      'sessionPort': 47331,
    });

    expect(capturedRequest?.platform, 'macos');
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(
      (structured['sessionHandle'] as Map<String, Object?>)['platform'],
      'macos',
    );
  });

  test('launch development tool accepts windows arguments', () async {
    CockpitLaunchDevelopmentSessionRequest? capturedRequest;
    final tool = CockpitLaunchDevelopmentSessionTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchDevelopmentSessionResult(
          sessionHandle: CockpitDevelopmentSessionHandle(
            developmentSessionId: 'dev-session-windows',
            platform: 'windows',
            deviceId: 'windows',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            appId: 'dev.cockpit.cockpit_demo',
            appBaseUrl: 'http://127.0.0.1:57331',
            supervisorBaseUrl: 'http://127.0.0.1:59331',
            remoteSessionHandle: CockpitRemoteSessionHandle(
              platform: 'windows',
              deviceId: 'windows',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              appId: 'dev.cockpit.cockpit_demo',
              host: '127.0.0.1',
              hostPort: 57331,
              devicePort: 47331,
              baseUrl: 'http://127.0.0.1:57331',
              launchedAt: DateTime.utc(2026, 3, 23),
            ),
            launchedAt: DateTime.utc(2026, 3, 23),
            reloadGeneration: 0,
          ),
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'dev-session-windows',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 0,
            lastStatusAt: DateTime.utc(2026, 3, 23),
          ),
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'projectDir': '/workspace/examples/cockpit_demo',
      'target': 'cockpit/main.dart',
      'platform': 'windows',
      'deviceId': 'windows',
      'sessionPort': 47331,
    });

    expect(capturedRequest?.platform, 'windows');
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(
      (structured['sessionHandle'] as Map<String, Object?>)['platform'],
      'windows',
    );
  });

  test('launch development tool accepts linux arguments', () async {
    CockpitLaunchDevelopmentSessionRequest? capturedRequest;
    final tool = CockpitLaunchDevelopmentSessionTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchDevelopmentSessionResult(
          sessionHandle: CockpitDevelopmentSessionHandle(
            developmentSessionId: 'dev-session-linux',
            platform: 'linux',
            deviceId: 'linux',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            appId: 'dev.cockpit.cockpit_demo',
            appBaseUrl: 'http://127.0.0.1:57331',
            supervisorBaseUrl: 'http://127.0.0.1:59331',
            remoteSessionHandle: CockpitRemoteSessionHandle(
              platform: 'linux',
              deviceId: 'linux',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              appId: 'dev.cockpit.cockpit_demo',
              host: '127.0.0.1',
              hostPort: 57331,
              devicePort: 47331,
              baseUrl: 'http://127.0.0.1:57331',
              launchedAt: DateTime.utc(2026, 3, 23),
            ),
            launchedAt: DateTime.utc(2026, 3, 23),
            reloadGeneration: 0,
          ),
          status: CockpitDevelopmentSessionStatus(
            developmentSessionId: 'dev-session-linux',
            state: CockpitDevelopmentSessionState.ready,
            appReachable: true,
            remoteSessionReachable: true,
            reloadGeneration: 0,
            lastStatusAt: DateTime.utc(2026, 3, 23),
          ),
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'projectDir': '/workspace/examples/cockpit_demo',
      'target': 'cockpit/main.dart',
      'platform': 'linux',
      'deviceId': 'linux',
      'sessionPort': 47331,
    });

    expect(capturedRequest?.platform, 'linux');
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(
      (structured['sessionHandle'] as Map<String, Object?>)['platform'],
      'linux',
    );
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
  reloadGeneration: 0,
);

CockpitDevelopmentSessionStatus _status(CockpitDevelopmentSessionState state) =>
    CockpitDevelopmentSessionStatus(
      developmentSessionId: 'dev-session-1',
      state: state,
      appReachable: state == CockpitDevelopmentSessionState.ready,
      remoteSessionReachable: state == CockpitDevelopmentSessionState.ready,
      reloadGeneration: 0,
      lastStatusAt: DateTime.utc(2026, 3, 23),
    );
