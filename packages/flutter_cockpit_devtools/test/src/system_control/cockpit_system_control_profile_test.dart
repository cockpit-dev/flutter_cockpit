import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/system_control/cockpit_system_control_profile.dart';
import 'package:test/test.dart';

void main() {
  test('system capability entries serialize explicit availability', () {
    const capability = CockpitSystemControlCapability(
      action: CockpitSystemControlAction.tap,
      plane: CockpitPlaneKind.deviceSystemPlane,
      availability: CockpitSystemControlAvailability.available,
      strategy: 'adb.shell.input.tap',
      requires: <String>['android device reachable by adb'],
      limitations: <String>['coordinate input has no semantic locator'],
      fallbackActions: <CockpitSystemControlAction>[
        CockpitSystemControlAction.runShell,
      ],
    );

    final json = capability.toJson();
    final decoded = CockpitSystemControlCapability.fromJson(json);

    expect(decoded, capability);
    expect(json['action'], 'tap');
    expect(json['availability'], 'available');
    expect(json['plane'], 'deviceSystemPlane');
    expect(json['strategy'], 'adb.shell.input.tap');
    expect(json['requires'], contains('android device reachable by adb'));
    expect(
      json['limitations'],
      contains('coordinate input has no semantic locator'),
    );
    expect(json['fallbackActions'], contains('runShell'));
  });

  test('profile exposes compact AI decision fields', () {
    const profile = CockpitSystemControlProfile(
      platform: 'ios',
      deviceId: '00008110-001234',
      appId: 'dev.cockpit.example',
      processId: 4242,
      adapter: 'ios.physical',
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.nativeUiPlane,
      ],
      capabilities: <CockpitSystemControlCapability>[
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.tap,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.webdriveragent',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
        ),
      ],
      recommendedNextStep: 'preferFlutterSemanticPlane',
    );

    final json = profile.toJson();

    expect(json['platform'], 'ios');
    expect(json['deviceId'], '00008110-001234');
    expect(json['appId'], 'dev.cockpit.example');
    expect(json['processId'], 4242);
    expect(json['adapter'], 'ios.physical');
    expect(json['preferredPlane'], 'flutterSemanticPlane');
    expect(json['fallbackOrder'], <String>[
      'flutterSemanticPlane',
      'nativeUiPlane',
    ]);
    expect(json['recommendedNextStep'], 'preferFlutterSemanticPlane');
    expect(json['availableActions'], isEmpty);
    expect(json['blockedActions'], contains('tap'));
    expect(json['unsupportedActions'], isEmpty);
  });
}
