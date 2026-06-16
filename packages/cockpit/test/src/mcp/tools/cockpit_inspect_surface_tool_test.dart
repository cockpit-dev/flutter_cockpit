import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/application/cockpit_inspect_surface_service.dart';
import 'package:cockpit/src/mcp/tools/cockpit_inspect_surface_tool.dart';
import 'package:cockpit/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'inspect_surface returns structured surface inspection content',
    () async {
      CockpitInspectSurfaceRequest? capturedRequest;
      final tool = CockpitInspectSurfaceTool(
        inspect: (request) async {
          capturedRequest = request;
          return CockpitInspectSurfaceResult(
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
            surfaceKind: CockpitSurfaceKind.flutterSemantic,
            selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
            recommendedNextStep: 'runNextCommand',
            routeName: '/details',
            diagnosticLevel: 'investigate',
            truncated: false,
          );
        },
      );

      final result = await tool.call(<String, Object?>{
        'targetJson': '/tmp/target.json',
        'androidDeviceId': 'emulator-5554',
        'profile': 'inspect',
      });

      expect(result['structuredContent'], isA<Map<String, Object?>>());
      expect(capturedRequest?.androidDeviceId, 'emulator-5554');
    },
  );
}
