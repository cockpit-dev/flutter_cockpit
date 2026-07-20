import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_read_target_service.dart';
import 'package:cockpit/src/mcp/tools/cockpit_read_target_tool.dart';
import 'package:cockpit/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test('read_target returns target-first structured content', () async {
    CockpitReadTargetRequest? capturedRequest;
    final tool = CockpitReadTargetTool(
      read: (request) async {
        capturedRequest = request;
        return CockpitReadTargetResult(
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
          capabilityProfile: CockpitCapabilityProfile(
            targetKind: CockpitTargetKind.flutterApp,
            surfaceKinds: <CockpitSurfaceKind>{
              CockpitSurfaceKind.flutterSemantic,
            },
            actionCapabilities: <CockpitActionCapability>{
              CockpitActionCapability.tap,
            },
            evidenceCapabilities: <CockpitEvidenceCapability>{
              CockpitEvidenceCapability.flutterScreenshot,
            },
          ),
          foregroundSurface: CockpitSurfaceKind.flutterSemantic,
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          fallbackTrail: const <CockpitPlaneKind>[
            CockpitPlaneKind.nativeUiPlane,
          ],
          recommendedNextStep: 'runNextCommand',
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'targetJson': '/tmp/target.json',
      'androidDeviceId': 'emulator-5554',
      'profile': 'minimal',
    });

    expect(result['structuredContent'], isA<Map<String, Object?>>());
    expect(capturedRequest?.androidDeviceId, 'emulator-5554');
  });
}
