import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/mcp/tools/cockpit_read_system_capabilities_tool.dart';
import 'package:cockpit/src/mcp/tools/cockpit_run_system_action_tool.dart';
import 'package:cockpit/src/system_control/cockpit_system_control_service.dart';
import 'package:test/test.dart';

void main() {
  test('read_system_capabilities exposes platform and device inputs', () {
    final tool = CockpitReadSystemCapabilitiesTool();

    final properties = tool.inputSchema['properties']! as Map<String, Object?>;

    expect(
      properties.keys,
      containsAll(<String>[
        'platform',
        'deviceId',
        'appId',
        'processId',
        'wdaUrl',
      ]),
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

  test('read_system_capabilities forwards WebDriverAgent metadata', () async {
    CockpitSystemControlDescribeRequest? capturedRequest;
    final tool = CockpitReadSystemCapabilitiesTool(
      describe: (request) async {
        capturedRequest = request;
        return const CockpitSystemControlDescribeResult(
          profile: CockpitSystemControlProfile(
            platform: 'ios',
            deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
            adapter: 'ios.simctl+xctest',
            preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
            fallbackOrder: <CockpitPlaneKind>[
              CockpitPlaneKind.flutterSemanticPlane,
              CockpitPlaneKind.nativeUiPlane,
              CockpitPlaneKind.deviceSystemPlane,
            ],
            capabilities: <CockpitSystemControlCapability>[
              CockpitSystemControlCapability(
                action: CockpitSystemControlAction.dismissSystemDialog,
                plane: CockpitPlaneKind.nativeUiPlane,
                availability: CockpitSystemControlAvailability.available,
                strategy: 'webdriveragent.alert.accept',
              ),
            ],
            recommendedNextStep: 'preferFlutterSemanticPlane',
          ),
          recommendedNextStep: 'preferFlutterSemanticPlane',
        );
      },
    );

    await tool.call(<String, Object?>{
      'platform': 'ios',
      'deviceId': '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'wdaUrl': 'http://127.0.0.1:8100',
    });

    expect(capturedRequest?.metadata['wdaUrl'], 'http://127.0.0.1:8100');
  });

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
      'wdaUrl': 'http://127.0.0.1:8100',
      'action': 'tap',
      'parameters': <String, Object?>{'x': 42, 'y': 88},
      'timeoutSeconds': 3,
    });

    expect(capturedRequest?.platform, 'android');
    expect(capturedRequest?.deviceId, 'emulator-5554');
    expect(capturedRequest?.appId, 'dev.cockpit.example');
    expect(capturedRequest?.processId, 4242);
    expect(capturedRequest?.metadata['wdaUrl'], 'http://127.0.0.1:8100');
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
