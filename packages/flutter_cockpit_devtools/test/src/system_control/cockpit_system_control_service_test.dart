import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/system_control/cockpit_system_control_adapter.dart';
import 'package:flutter_cockpit_devtools/src/system_control/cockpit_system_control_service.dart';
import 'package:test/test.dart';

void main() {
  test('android profile reports executable adb system controls', () async {
    final service = CockpitSystemControlService();

    final result = await service.describe(
      const CockpitSystemControlDescribeRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
      ),
    );

    expect(result.profile.platform, 'android');
    expect(result.profile.adapter, 'android.adb');
    expect(
      result.profile.preferredPlane,
      CockpitPlaneKind.flutterSemanticPlane,
    );
    expect(result.profile.fallbackOrder, <CockpitPlaneKind>[
      CockpitPlaneKind.flutterSemanticPlane,
      CockpitPlaneKind.nativeUiPlane,
      CockpitPlaneKind.deviceSystemPlane,
    ]);
    expect(
      result.profile.availableActions,
      contains(CockpitSystemControlAction.tap),
    );
    expect(
      result.profile.availableActions,
      contains(CockpitSystemControlAction.captureScreenshot),
    );
    expect(
      result.profile
          .capabilityFor(CockpitSystemControlAction.startRecording)
          ?.strategy,
      'adb.shell.screenrecord',
    );
    expect(result.recommendedNextStep, 'preferFlutterSemanticPlane');
  });

  test('android profile blocks device actions without a device id', () async {
    final service = CockpitSystemControlService();

    final result = await service.describe(
      const CockpitSystemControlDescribeRequest(platform: 'android'),
    );

    expect(
      result.profile.availableActions,
      isNot(contains(CockpitSystemControlAction.tap)),
    );
    expect(
      result.profile.blockedActions,
      contains(CockpitSystemControlAction.tap),
    );
    expect(
      result.profile
          .capabilityFor(CockpitSystemControlAction.captureScreenshot)
          ?.availability,
      CockpitSystemControlAvailability.blocked,
    );
    expect(
      result.profile.capabilityFor(CockpitSystemControlAction.tap)?.requires,
      contains('device id'),
    );
  });

  test(
    'ios physical profile reports XCTest dependency instead of fake support',
    () async {
      final service = CockpitSystemControlService();

      final result = await service.describe(
        const CockpitSystemControlDescribeRequest(
          platform: 'ios',
          deviceId: '00008110-001234',
        ),
      );

      expect(result.profile.adapter, 'ios.physical');
      expect(
        result.profile.availableActions,
        isNot(contains(CockpitSystemControlAction.tap)),
      );
      expect(
        result.profile.blockedActions,
        contains(CockpitSystemControlAction.tap),
      );
      final tap = result.profile.capabilityFor(CockpitSystemControlAction.tap);
      expect(tap?.availability, CockpitSystemControlAvailability.blocked);
      expect(
        tap?.requires,
        contains('developer-signed XCTest/WebDriverAgent runner'),
      );
      expect(result.recommendedNextStep, 'preferFlutterSemanticPlane');
    },
  );

  test('unknown platform reports unsupported capability profile', () async {
    final service = CockpitSystemControlService();

    final result = await service.describe(
      const CockpitSystemControlDescribeRequest(platform: 'freebsd'),
    );

    expect(result.profile.platform, 'freebsd');
    expect(result.profile.adapter, 'unsupported');
    expect(
      result.profile.unsupportedActions,
      contains(CockpitSystemControlAction.tap),
    );
    expect(result.recommendedNextStep, 'useFlutterOrHostFallback');
  });

  test(
    'web profile blocks browser bridge actions until bridge is wired',
    () async {
      final service = CockpitSystemControlService();

      final result = await service.describe(
        const CockpitSystemControlDescribeRequest(
          platform: 'web',
          deviceId: 'chrome',
        ),
      );

      expect(result.profile.adapter, 'browser.dom+host-recording');
      expect(result.profile.availableActions, isEmpty);
      expect(result.profile.blockedActions, <CockpitSystemControlAction>[
        CockpitSystemControlAction.tap,
        CockpitSystemControlAction.typeText,
        CockpitSystemControlAction.captureScreenshot,
        CockpitSystemControlAction.startRecording,
        CockpitSystemControlAction.stopRecording,
      ]);
      expect(
        result.profile
            .capabilityFor(CockpitSystemControlAction.captureScreenshot)
            ?.requires,
        contains('browser driver or bridge'),
      );
    },
  );

  test(
    'desktop profile enables evidence actions only with window target',
    () async {
      final service = CockpitSystemControlService();

      final withoutTarget = await service.describe(
        const CockpitSystemControlDescribeRequest(platform: 'macos'),
      );
      expect(
        withoutTarget.profile.blockedActions,
        contains(CockpitSystemControlAction.captureScreenshot),
      );
      expect(
        withoutTarget.profile.blockedActions,
        contains(CockpitSystemControlAction.startRecording),
      );

      final withTarget = await service.describe(
        const CockpitSystemControlDescribeRequest(
          platform: 'macos',
          appId: 'dev.cockpit.example',
        ),
      );

      expect(withTarget.profile.appId, 'dev.cockpit.example');
      expect(
        withTarget.profile.availableActions,
        contains(CockpitSystemControlAction.captureScreenshot),
      );
      expect(
        withTarget.profile.availableActions,
        contains(CockpitSystemControlAction.startRecording),
      );
      expect(
        withTarget.profile.availableActions,
        contains(CockpitSystemControlAction.stopRecording),
      );

      final macosProcessOnly = await service.describe(
        const CockpitSystemControlDescribeRequest(
          platform: 'macos',
          processId: 4242,
        ),
      );
      expect(
        macosProcessOnly.profile.blockedActions,
        contains(CockpitSystemControlAction.captureScreenshot),
      );

      final windowsProcessOnly = await service.describe(
        const CockpitSystemControlDescribeRequest(
          platform: 'windows',
          processId: 4242,
        ),
      );
      expect(
        windowsProcessOnly.profile.availableActions,
        contains(CockpitSystemControlAction.captureScreenshot),
      );
    },
  );

  test('available capabilities resolve to executable commands', () async {
    const registry = CockpitSystemControlRegistry();
    for (final entry in <({String platform, String deviceId})>[
      (platform: 'android', deviceId: 'emulator-5554'),
      (platform: 'ios', deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC'),
      (platform: 'macos', deviceId: 'host'),
      (platform: 'windows', deviceId: 'host'),
      (platform: 'linux', deviceId: 'host'),
      (platform: 'web', deviceId: 'chrome'),
    ]) {
      final adapter = registry.resolve(entry.platform);
      final profile = adapter.describe(
        CockpitSystemControlTargetContext(
          deviceId: entry.deviceId,
          appId:
              entry.platform == 'macos' ||
                  entry.platform == 'windows' ||
                  entry.platform == 'linux'
              ? 'dev.cockpit.example'
              : null,
        ),
      );
      for (final capability in profile.capabilities.where(
        (capability) =>
            capability.availability ==
            CockpitSystemControlAvailability.available,
      )) {
        if (_isEvidenceAction(capability.action)) {
          continue;
        }
        final request = CockpitSystemControlActionRequest(
          platform: entry.platform,
          deviceId: entry.deviceId,
          action: capability.action,
          parameters: _validParametersFor(capability.action),
        );
        final command = adapter.resolveCommand(request);

        expect(
          command.hasError,
          isFalse,
          reason:
              '${entry.platform}.${capability.action.name} is declared available but resolves ${command.errorCode}: ${command.errorMessage}',
        );
        expect(command.executable, isNot(isEmpty));
      }
    }
  });
}

bool _isEvidenceAction(CockpitSystemControlAction action) {
  return switch (action) {
    CockpitSystemControlAction.captureScreenshot ||
    CockpitSystemControlAction.startRecording ||
    CockpitSystemControlAction.stopRecording => true,
    _ => false,
  };
}

Map<String, Object?> _validParametersFor(CockpitSystemControlAction action) {
  return switch (action) {
    CockpitSystemControlAction.tap => const <String, Object?>{'x': 10, 'y': 20},
    CockpitSystemControlAction.longPress => const <String, Object?>{
      'x': 10,
      'y': 20,
      'durationMs': 800,
    },
    CockpitSystemControlAction.drag => const <String, Object?>{
      'startX': 10,
      'startY': 20,
      'endX': 30,
      'endY': 40,
      'durationMs': 300,
    },
    CockpitSystemControlAction.typeText => const <String, Object?>{
      'text': 'hello',
    },
    CockpitSystemControlAction.grantPermission => const <String, Object?>{
      'packageId': 'dev.cockpit.example',
      'permission': 'android.permission.CAMERA',
    },
    CockpitSystemControlAction.openUrl => const <String, Object?>{
      'url': 'https://example.com',
    },
    CockpitSystemControlAction.captureScreenshot => const <String, Object?>{
      'outputPath': '/tmp/cockpit-system-screenshot.png',
    },
    CockpitSystemControlAction.startRecording => const <String, Object?>{
      'name': 'system-recording',
    },
    CockpitSystemControlAction.stopRecording => const <String, Object?>{},
    CockpitSystemControlAction.runShell => const <String, Object?>{
      'command': <String>['echo', 'ok'],
    },
    CockpitSystemControlAction.pressBack ||
    CockpitSystemControlAction.pressHome ||
    CockpitSystemControlAction.activateWindow ||
    CockpitSystemControlAction.dismissSystemDialog ||
    CockpitSystemControlAction.readUiTree ||
    CockpitSystemControlAction.readSystemState => const <String, Object?>{},
  };
}
