import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_launch_app_tool.dart';
import 'package:test/test.dart';

void main() {
  test('launch_app allows omitting target so services can infer it', () async {
    CockpitLaunchAppRequest? capturedRequest;
    final tool = CockpitLaunchAppTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchAppResult(
          app: CockpitAppHandle.fromDevelopmentSession(
            CockpitDevelopmentSessionHandle(
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
            ),
          ),
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'projectDir': '/workspace/examples/cockpit_demo',
      'platform': 'macos',
      'deviceId': 'macos',
      'sessionPort': 57331,
    });

    expect(result['structuredContent'], isA<Map<String, Object?>>());
    expect(capturedRequest?.target, isNull);
  });

  test('launch_app accepts flavor for consumer-app launch flows', () async {
    CockpitLaunchAppRequest? capturedRequest;
    final tool = CockpitLaunchAppTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchAppResult(
          app: CockpitAppHandle.fromDevelopmentSession(
            CockpitDevelopmentSessionHandle(
              developmentSessionId: 'dev-session-1',
              platform: 'android',
              deviceId: 'emulator-5554',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              appId: 'dev.cockpit.demo',
              appBaseUrl: 'http://127.0.0.1:57331',
              supervisorBaseUrl: 'http://127.0.0.1:59331',
              launchedAt: DateTime.utc(2026, 3, 30),
              reloadGeneration: 0,
            ),
          ),
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'projectDir': '/workspace/examples/cockpit_demo',
      'platform': 'android',
      'deviceId': 'emulator-5554',
      'sessionPort': 57331,
      'flavor': 'staging',
    });

    expect(result['structuredContent'], isA<Map<String, Object?>>());
    expect(capturedRequest?.flavor, 'staging');
  });

  test('launch_app defaults macos deviceId the same way as the CLI', () async {
    CockpitLaunchAppRequest? capturedRequest;
    final tool = CockpitLaunchAppTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchAppResult(
          app: CockpitAppHandle.fromDevelopmentSession(
            CockpitDevelopmentSessionHandle(
              developmentSessionId: 'dev-session-1',
              platform: 'macos',
              deviceId: request.deviceId,
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              appId: 'dev.cockpit.demo',
              appBaseUrl: 'http://127.0.0.1:57331',
              supervisorBaseUrl: 'http://127.0.0.1:59331',
              launchedAt: DateTime.utc(2026, 3, 30),
              reloadGeneration: 0,
            ),
          ),
        );
      },
    );

    await tool.call(<String, Object?>{
      'projectDir': '/workspace/examples/cockpit_demo',
      'platform': 'macos',
      'sessionPort': 57331,
    });

    expect(tool.inputSchema['required'], isNot(contains('deviceId')));
    expect(capturedRequest?.deviceId, 'macos');
  });

  test('launch_app still requires an explicit mobile deviceId', () {
    final tool = CockpitLaunchAppTool(
      launch: (_) async => throw StateError('unexpected launch'),
    );

    expect(
      () => tool.call(<String, Object?>{
        'projectDir': '/workspace/examples/cockpit_demo',
        'platform': 'android',
        'sessionPort': 57331,
      }),
      throwsA(isA<CockpitMcpError>()),
    );
  });
}
