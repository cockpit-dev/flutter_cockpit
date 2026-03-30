import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_remote_session_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_launch_remote_session_tool.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
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
            persistedHandlePath: '/tmp/session_handle.json',
          );
        },
      );

      expect(tool.inputSchema['required'], <String>[
        'project_dir',
        'platform',
        'device_id',
        'session_port',
      ]);

      final result = await tool.call(<String, Object?>{
        'project_dir': '/workspace/examples/cockpit_demo',
        'platform': 'android',
        'device_id': 'emulator-5554',
        'session_port': 47331,
        'launch_timeout_seconds': 90,
        'persist_handle_path': '/tmp/session_handle.json',
      });

      expect(capturedRequest?.projectDir, '/workspace/examples/cockpit_demo');
      expect(capturedRequest?.deviceId, 'emulator-5554');
      expect(capturedRequest?.launchTimeout, const Duration(seconds: 90));
      expect(capturedRequest?.target, isNull);

      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(
        structuredContent['session_handle_path'],
        '/tmp/session_handle.json',
      );
      expect(
        (structuredContent['health'] as Map<String, Object?>)['session_id'],
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
        'project_dir': '/workspace/examples/cockpit_demo',
        'target': 'lib/main.dart',
        'platform': 'android',
        'device_id': 'emulator-5554',
        'session_port': 47331,
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
      'project_dir': '/workspace/examples/cockpit_demo',
      'target': 'cockpit/main.dart',
      'platform': 'macos',
      'device_id': 'macos',
      'session_port': 47331,
    });

    expect(capturedRequest?.platform, 'macos');
    final structuredContent =
        result['structuredContent'] as Map<String, Object?>;
    expect(
      (structuredContent['session_handle'] as Map<String, Object?>)['platform'],
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
      'project_dir': '/workspace/examples/cockpit_demo',
      'target': 'cockpit/main.dart',
      'platform': 'windows',
      'device_id': 'windows',
      'session_port': 47331,
    });

    expect(capturedRequest?.platform, 'windows');
    final structuredContent =
        result['structuredContent'] as Map<String, Object?>;
    expect(
      (structuredContent['session_handle'] as Map<String, Object?>)['platform'],
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
      'project_dir': '/workspace/examples/cockpit_demo',
      'target': 'cockpit/main.dart',
      'platform': 'linux',
      'device_id': 'linux',
      'session_port': 47331,
    });

    expect(capturedRequest?.platform, 'linux');
    final structuredContent =
        result['structuredContent'] as Map<String, Object?>;
    expect(
      (structuredContent['session_handle'] as Map<String, Object?>)['platform'],
      'linux',
    );
  });
}
