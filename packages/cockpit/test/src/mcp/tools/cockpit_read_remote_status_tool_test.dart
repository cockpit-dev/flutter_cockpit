import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_read_remote_status_service.dart';
import 'package:cockpit/src/mcp/tools/cockpit_read_remote_status_tool.dart';
import 'package:test/test.dart';

void main() {
  test('read_remote_status parses the profile and returns content', () async {
    CockpitReadRemoteStatusRequest? capturedRequest;
    final tool = CockpitReadRemoteStatusTool(
      read: (request) async {
        capturedRequest = request;
        return CockpitReadRemoteStatusResult(
          sessionId: 'session-1',
          platform: 'macos',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'macos',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
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
      'profile': 'minimal',
    });

    expect(capturedRequest?.resultProfile.name.jsonValue, 'minimal');
    expect(result['structuredContent'], isA<Map<String, Object?>>());
  });
}
