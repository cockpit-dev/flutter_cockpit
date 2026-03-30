import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_query_remote_session_service.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_error.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_query_remote_session_tool.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'query tool exposes session reference inputs and returns MCP-safe structured content',
    () async {
      CockpitQueryRemoteSessionRequest? capturedRequest;
      final handle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: 'simulator',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        host: '127.0.0.1',
        hostPort: 58421,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:58421',
        launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
      );
      final tool = CockpitQueryRemoteSessionTool(
        query: (request) async {
          capturedRequest = request;
          return CockpitQueryRemoteSessionResult(
            status: CockpitRemoteSessionStatus(
              sessionId: 'query-tool-demo',
              platform: 'ios',
              transportType: 'remoteHttp',
              currentRouteName: '/ready',
              capabilities: CockpitCapabilities(
                platform: 'ios',
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
              snapshot: CockpitSnapshot(routeName: '/ready'),
            ),
            sessionHandle: handle,
            recommendedNextStep: 'ready_for_commands',
          );
        },
      );

      expect(
        (tool.inputSchema['properties'] as Map<String, Object?>).keys,
        containsAll(<String>['session_handle', 'session_handle_path']),
      );

      final result = await tool.call(<String, Object?>{
        'session_handle': handle.toJson(),
      });

      expect(capturedRequest?.sessionHandle?.toJson(), handle.toJson());
      final structuredContent =
          result['structuredContent'] as Map<String, Object?>;
      expect(structuredContent['recommended_next_step'], 'ready_for_commands');
      expect(
        (structuredContent['status'] as Map<String, Object?>)['session_id'],
        'query-tool-demo',
      );
    },
  );

  test('query tool maps service errors into MCP errors', () async {
    final tool = CockpitQueryRemoteSessionTool(
      query: (_) async => throw const CockpitApplicationServiceException(
        code: 'missingSessionReference',
        message: 'Session reference is required.',
      ),
    );

    expect(
      () => tool.call(const <String, Object?>{}),
      throwsA(
        isA<CockpitMcpError>().having(
          (error) => error.data['serviceCode'],
          'serviceCode',
          'missingSessionReference',
        ),
      ),
    );
  });
}
