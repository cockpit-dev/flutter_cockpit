import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/mcp/cockpit_mcp_error.dart';
import 'package:cockpit/src/application/cockpit_launch_target_service.dart';
import 'package:cockpit/src/mcp/tools/cockpit_launch_target_tool.dart';
import 'package:cockpit/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'launch_target launches a flutter target and returns structured content',
    () async {
      CockpitLaunchTargetRequest? capturedRequest;
      final tool = CockpitLaunchTargetTool(
        launch: (request) async {
          capturedRequest = request;
          return CockpitLaunchTargetResult(
            target: CockpitTargetHandle(
              targetId: 'dev.cockpit.demo',
              targetKind: CockpitTargetKind.flutterApp,
              platform: 'android',
              deviceId: 'emulator-5554',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              connection: const CockpitTargetConnection(
                baseUrl: 'http://127.0.0.1:57331',
              ),
              launchedAt: DateTime.utc(2026, 4, 11),
            ),
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'projectDir': '/workspace/examples/cockpit_demo',
        'platform': 'android',
        'deviceId': 'emulator-5554',
        'sessionPort': 57331,
      });

      expect(capturedRequest?.targetKind, CockpitTargetKind.flutterApp);
      expect(result['structuredContent'], isA<Map<String, Object?>>());
    },
  );

  test(
    'launch_target defaults macos deviceId the same way as the CLI',
    () async {
      CockpitLaunchTargetRequest? capturedRequest;
      final tool = CockpitLaunchTargetTool(
        launch: (request) async {
          capturedRequest = request;
          return CockpitLaunchTargetResult(
            target: CockpitTargetHandle(
              targetId: 'dev.cockpit.demo',
              targetKind: CockpitTargetKind.flutterApp,
              platform: 'macos',
              deviceId: request.deviceId,
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              connection: const CockpitTargetConnection(
                baseUrl: 'http://127.0.0.1:57331',
              ),
              launchedAt: DateTime.utc(2026, 4, 11),
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
      expect(capturedRequest?.targetKind, CockpitTargetKind.flutterApp);
    },
  );

  test('launch_target still requires an explicit web deviceId', () {
    final tool = CockpitLaunchTargetTool(
      launch: (_) async => throw StateError('unexpected launch'),
    );

    expect(
      () => tool.call(<String, Object?>{
        'projectDir': '/workspace/examples/cockpit_demo',
        'platform': 'web',
        'sessionPort': 57331,
      }),
      throwsA(isA<CockpitMcpError>()),
    );
  });
}
