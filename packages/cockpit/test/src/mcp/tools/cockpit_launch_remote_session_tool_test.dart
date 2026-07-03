import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_application_service_exception.dart';
import 'package:cockpit/src/application/cockpit_launch_remote_session_service.dart';
import 'package:cockpit/src/application/cockpit_session_registry.dart';
import 'package:cockpit/src/mcp/cockpit_mcp_error.dart';
import 'package:cockpit/src/mcp/tools/cockpit_launch_remote_session_tool.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'launch tool exposes required inputs and returns MCP-safe structured content',
    () async {
      CockpitLaunchRemoteSessionRequest? capturedRequest;
      final tool = CockpitLaunchRemoteSessionTool(
        launch: (request) async {
          capturedRequest = request;
          return CockpitLaunchRemoteSessionResult(
            sessionHandle: CockpitRemoteSessionHandle(
              platform: 'android',
              deviceId: 'emulator-5554',
              projectDir: request.projectDir,
              target: request.target ?? 'cockpit/main.dart',
              appId: 'dev.cockpit.cockpit_demo',
              host: '127.0.0.1',
              hostPort: 58421,
              devicePort: request.sessionPort,
              baseUrl: 'http://127.0.0.1:58421',
              launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
            ),
            health: CockpitRemoteSessionStatus(
              sessionId: 'launch-tool-demo',
              platform: 'android',
              transportType: 'remoteHttp',
              currentRouteName: '/home',
              capabilities: CockpitCapabilities(
                platform: 'android',
                transportType: 'remoteHttp',
                supportsInAppControl: true,
                supportsFlutterViewCapture: true,
                supportsNativeScreenCapture: true,
                supportsHostAutomation: false,
                supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
                supportedLocatorStrategies: CockpitLocatorKind.values,
              ),
              recordingCapabilities: CockpitRecordingCapabilities(
                supportsNativeRecording: true,
                preferredAcceptanceRecordingKind:
                    CockpitRecordingKind.nativeScreen,
              ),
              snapshot: CockpitSnapshot(routeName: '/home'),
            ),
            persistedHandlePath: '/tmp/sessionHandle.json',
          );
        },
      );

      expect(tool.inputSchema['required'], <String>[
        'projectDir',
        'platform',
        'deviceId',
        'sessionPort',
      ]);

      final result = await tool.call(<String, Object?>{
        'projectDir': '/workspace/examples/cockpit_demo',
        'platform': 'android',
        'deviceId': 'emulator-5554',
        'sessionPort': 47331,
        'launchTimeoutSeconds': 90,
        'persistHandlePath': '/tmp/sessionHandle.json',
      });

      expect(capturedRequest?.projectDir, '/workspace/examples/cockpit_demo');
      expect(capturedRequest?.deviceId, 'emulator-5554');
      expect(capturedRequest?.launchTimeout, const Duration(seconds: 90));
      expect(capturedRequest?.target, isNull);

      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(structuredContent['sessionHandlePath'], '/tmp/sessionHandle.json');
      expect(
        (structuredContent['health'] as Map<String, Object?>)['sessionId'],
        'launch-tool-demo',
      );
      expect(result['content'], isA<List<Object?>>());
    },
  );

  test('launch tool maps service errors into MCP errors', () async {
    final tool = CockpitLaunchRemoteSessionTool(
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
      throwsA(
        isA<CockpitMcpError>().having(
          (error) => error.data['serviceCode'],
          'serviceCode',
          'launchFailed',
        ),
      ),
    );
  });

  test('launch tool accepts macos arguments', () async {
    CockpitLaunchRemoteSessionRequest? capturedRequest;
    final tool = CockpitLaunchRemoteSessionTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchRemoteSessionResult(
          sessionHandle: CockpitRemoteSessionHandle(
            platform: 'macos',
            deviceId: 'macos',
            projectDir: request.projectDir,
            target: request.target ?? 'cockpit/main.dart',
            appId: 'dev.cockpit.cockpit_demo',
            host: '127.0.0.1',
            hostPort: 58421,
            devicePort: request.sessionPort,
            baseUrl: 'http://127.0.0.1:58421',
            launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
          ),
          health: CockpitRemoteSessionStatus(
            sessionId: 'launch-tool-macos',
            platform: 'macos',
            transportType: 'remoteHttp',
            currentRouteName: '/home',
            capabilities: CockpitCapabilities(
              platform: 'macos',
              transportType: 'remoteHttp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: true,
              supportsHostAutomation: true,
              supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
              supportedLocatorStrategies: CockpitLocatorKind.values,
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: true,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            snapshot: CockpitSnapshot(routeName: '/home'),
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
    final structuredContent =
        result['structuredContent'] as Map<String, Object?>;
    expect(
      (structuredContent['sessionHandle'] as Map<String, Object?>)['platform'],
      'macos',
    );
  });

  test('launch tool accepts windows arguments', () async {
    CockpitLaunchRemoteSessionRequest? capturedRequest;
    final tool = CockpitLaunchRemoteSessionTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchRemoteSessionResult(
          sessionHandle: CockpitRemoteSessionHandle(
            platform: 'windows',
            deviceId: 'windows',
            projectDir: request.projectDir,
            target: request.target ?? 'cockpit/main.dart',
            appId: 'dev.cockpit.cockpit_demo',
            host: '127.0.0.1',
            hostPort: 58421,
            devicePort: request.sessionPort,
            baseUrl: 'http://127.0.0.1:58421',
            launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
          ),
          health: CockpitRemoteSessionStatus(
            sessionId: 'launch-tool-windows',
            platform: 'windows',
            transportType: 'remoteHttp',
            currentRouteName: '/home',
            capabilities: CockpitCapabilities(
              platform: 'windows',
              transportType: 'remoteHttp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: true,
              supportsHostAutomation: true,
              supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
              supportedLocatorStrategies: CockpitLocatorKind.values,
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: true,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            snapshot: CockpitSnapshot(routeName: '/home'),
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
    final structuredContent =
        result['structuredContent'] as Map<String, Object?>;
    expect(
      (structuredContent['sessionHandle'] as Map<String, Object?>)['platform'],
      'windows',
    );
  });

  test('launch tool accepts linux arguments', () async {
    CockpitLaunchRemoteSessionRequest? capturedRequest;
    final tool = CockpitLaunchRemoteSessionTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchRemoteSessionResult(
          sessionHandle: CockpitRemoteSessionHandle(
            platform: 'linux',
            deviceId: 'linux',
            projectDir: request.projectDir,
            target: request.target ?? 'cockpit/main.dart',
            appId: 'dev.cockpit.cockpit_demo',
            host: '127.0.0.1',
            hostPort: 58421,
            devicePort: request.sessionPort,
            baseUrl: 'http://127.0.0.1:58421',
            launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
          ),
          health: CockpitRemoteSessionStatus(
            sessionId: 'launch-tool-linux',
            platform: 'linux',
            transportType: 'remoteHttp',
            currentRouteName: '/home',
            capabilities: CockpitCapabilities(
              platform: 'linux',
              transportType: 'remoteHttp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: true,
              supportsHostAutomation: true,
              supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
              supportedLocatorStrategies: CockpitLocatorKind.values,
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: true,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            snapshot: CockpitSnapshot(routeName: '/home'),
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
    final structuredContent =
        result['structuredContent'] as Map<String, Object?>;
    expect(
      (structuredContent['sessionHandle'] as Map<String, Object?>)['platform'],
      'linux',
    );
  });

  test(
    'launch tool records remote sessions with normalized readiness state',
    () async {
      final registry = CockpitSessionRegistry(
        now: () => DateTime.utc(2026, 3, 21, 0, 0, 1),
      );
      final tool = CockpitLaunchRemoteSessionTool(
        sessionRegistry: registry,
        launch: (request) async => CockpitLaunchRemoteSessionResult(
          sessionHandle: CockpitRemoteSessionHandle(
            platform: 'windows',
            deviceId: 'windows',
            projectDir: request.projectDir,
            target: request.target ?? 'cockpit/main.dart',
            appId: 'dev.cockpit.review_demo',
            host: '127.0.0.1',
            hostPort: 58421,
            devicePort: request.sessionPort,
            baseUrl: 'http://127.0.0.1:58421',
            launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
          ),
          health: CockpitRemoteSessionStatus(
            sessionId: 'launch-tool-registry',
            platform: 'windows',
            transportType: 'remoteHttp',
            currentRouteName: '/home',
            capabilities: CockpitCapabilities(
              platform: 'windows',
              transportType: 'remoteHttp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: true,
              supportsHostAutomation: true,
              supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
              supportedLocatorStrategies: CockpitLocatorKind.values,
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: true,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            snapshot: CockpitSnapshot(routeName: '/home'),
          ),
        ),
      );

      await tool.call(<String, Object?>{
        'projectDir': '/workspace/examples/cockpit_demo',
        'platform': 'windows',
        'deviceId': 'windows',
        'sessionPort': 47331,
      });

      final record = registry.remoteSessionByAppId('dev.cockpit.review_demo');
      expect(record, isNotNull);
      expect(record?.recommendedNextStep, 'ready_for_commands');
    },
  );

  test('launch tool accepts launch configuration payloads', () async {
    CockpitLaunchRemoteSessionRequest? capturedRequest;
    final tool = CockpitLaunchRemoteSessionTool(
      launch: (request) async {
        capturedRequest = request;
        return CockpitLaunchRemoteSessionResult(
          sessionHandle: CockpitRemoteSessionHandle(
            platform: 'android',
            deviceId: 'emulator-5554',
            projectDir: request.projectDir,
            target: request.target ?? 'cockpit/main.dart',
            appId: 'dev.cockpit.cockpit_demo',
            host: '127.0.0.1',
            hostPort: 58421,
            devicePort: request.sessionPort,
            baseUrl: 'http://127.0.0.1:58421',
            launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
          ),
          health: CockpitRemoteSessionStatus(
            sessionId: 'launch-tool-demo',
            platform: 'android',
            transportType: 'remoteHttp',
            currentRouteName: '/home',
            capabilities: CockpitCapabilities(
              platform: 'android',
              transportType: 'remoteHttp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: true,
              supportsHostAutomation: false,
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: true,
            ),
            snapshot: CockpitSnapshot(routeName: '/home'),
          ),
        );
      },
    );

    await tool.call(<String, Object?>{
      'projectDir': '/workspace/examples/cockpit_demo',
      'platform': 'android',
      'deviceId': 'emulator-5554',
      'sessionPort': 47331,
      'dartDefines': <String>['API_URL=https://example.test'],
      'dartDefineFromFiles': <String>['config/dev.json'],
      'flutterArgs': <String>['--track-widget-creation'],
      'environment': <String, Object?>{'API_TOKEN': 'secret'},
    });

    expect(capturedRequest?.launchConfiguration.dartDefines, <String>[
      'API_URL=https://example.test',
    ]);
    expect(capturedRequest?.launchConfiguration.dartDefineFromFiles, <String>[
      'config/dev.json',
    ]);
    expect(capturedRequest?.launchConfiguration.flutterArgs, <String>[
      '--track-widget-creation',
    ]);
    expect(capturedRequest?.launchConfiguration.environment, <String, String>{
      'API_TOKEN': 'secret',
    });
  });
}
