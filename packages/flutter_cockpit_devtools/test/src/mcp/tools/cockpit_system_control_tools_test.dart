import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_read_system_capabilities_tool.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_run_system_action_tool.dart';
import 'package:flutter_cockpit_devtools/src/system_control/cockpit_system_control_service.dart';
import 'package:test/test.dart';

void main() {
  test('read_system_capabilities exposes platform and device inputs', () {
    final tool = CockpitReadSystemCapabilitiesTool();

    final properties = tool.inputSchema['properties']! as Map<String, Object?>;

    expect(
      properties.keys,
      containsAll(<String>['platform', 'deviceId', 'appId', 'processId']),
    );
    expect(tool.annotations.readOnly, isTrue);
  });

  test(
    'read_system_capabilities returns structured capability content',
    () async {
      final tool = CockpitReadSystemCapabilitiesTool(
        describe: (_) async => const CockpitSystemControlDescribeResult(
          profile: CockpitSystemControlProfile(
            platform: 'android',
            deviceId: 'emulator-5554',
            adapter: 'android.adb',
            preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
            fallbackOrder: <CockpitPlaneKind>[
              CockpitPlaneKind.flutterSemanticPlane,
              CockpitPlaneKind.nativeUiPlane,
              CockpitPlaneKind.deviceSystemPlane,
            ],
            capabilities: <CockpitSystemControlCapability>[
              CockpitSystemControlCapability(
                action: CockpitSystemControlAction.tap,
                plane: CockpitPlaneKind.deviceSystemPlane,
                availability: CockpitSystemControlAvailability.available,
                strategy: 'adb.shell.input.tap',
              ),
            ],
            recommendedNextStep: 'preferFlutterSemanticPlane',
          ),
          recommendedNextStep: 'preferFlutterSemanticPlane',
        ),
      );

      final result = await tool.call(<String, Object?>{
        'platform': 'android',
        'deviceId': 'emulator-5554',
      });

      final structured = result['structuredContent'] as Map<String, Object?>;
      expect(structured['platform'], 'android');
      expect(structured['availableActions'], contains('tap'));
    },
  );

  test('run_system_action forwards action arguments to the service', () async {
    CockpitSystemControlActionRequest? capturedRequest;
    final tool = CockpitRunSystemActionTool(
      runAction: (request) async {
        capturedRequest = request;
        return const CockpitSystemControlActionResult(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.tap,
          availability: CockpitSystemControlAvailability.available,
          success: true,
          command: <String>['adb', '-s', 'emulator-5554', 'shell', 'input'],
          recommendedNextStep: 'readPostActionState',
        );
      },
    );

    final result = await tool.call(<String, Object?>{
      'platform': 'android',
      'deviceId': 'emulator-5554',
      'appId': 'dev.cockpit.example',
      'processId': 4242,
      'action': 'tap',
      'parameters': <String, Object?>{'x': 42, 'y': 88},
      'timeoutSeconds': 3,
    });

    expect(capturedRequest?.platform, 'android');
    expect(capturedRequest?.deviceId, 'emulator-5554');
    expect(capturedRequest?.appId, 'dev.cockpit.example');
    expect(capturedRequest?.processId, 4242);
    expect(capturedRequest?.action, CockpitSystemControlAction.tap);
    expect(capturedRequest?.parameters['x'], 42);
    expect(capturedRequest?.timeout, const Duration(seconds: 3));
    final structured = result['structuredContent'] as Map<String, Object?>;
    expect(structured['success'], isTrue);
  });

  test('run_system_action is annotated as potentially destructive', () {
    final tool = CockpitRunSystemActionTool();

    expect(tool.annotations.readOnly, isFalse);
    expect(tool.annotations.destructive, isTrue);
  });

  test('run_system_action schema exposes every system action', () {
    final tool = CockpitRunSystemActionTool();

    final properties = tool.inputSchema['properties']! as Map<String, Object?>;
    final action = properties['action']! as Map<String, Object?>;

    expect(
      action['enum'],
      CockpitSystemControlAction.values
          .map((action) => action.name)
          .toList(growable: false),
    );
  });
}
