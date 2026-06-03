import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cockpit_system_control_action.dart';
import '../cockpit_system_control_adapter.dart';
import '../cockpit_system_control_profile.dart';

final class CockpitIosSystemControlAdapter
    implements CockpitSystemControlAdapter {
  const CockpitIosSystemControlAdapter();

  @override
  String get platform => 'ios';

  @override
  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  ) {
    final deviceId = target.deviceId;
    if (_looksLikeIosSimulatorDeviceId(deviceId)) {
      return CockpitSystemControlProfile(
        platform: platform,
        deviceId: deviceId,
        appId: target.appId,
        processId: target.processId,
        adapter: 'ios.simctl+xctest',
        preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
        fallbackOrder: const <CockpitPlaneKind>[
          CockpitPlaneKind.flutterSemanticPlane,
          CockpitPlaneKind.nativeUiPlane,
          CockpitPlaneKind.deviceSystemPlane,
        ],
        recommendedNextStep: 'preferFlutterSemanticPlane',
        capabilities: const <CockpitSystemControlCapability>[
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.tap,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.webdriveragent',
            requires: <String>[
              'booted simulator',
              'XCTest/WebDriverAgent runner',
            ],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.dismissSystemDialog,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.springboard',
            requires: <String>['XCTest/WebDriverAgent runner'],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.openUrl,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.openurl',
            requires: <String>['xcrun', 'simulator device id'],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.captureScreenshot,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.io.screenshot',
            requires: <String>['xcrun', 'booted simulator'],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.startRecording,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.io.recordVideo',
            requires: <String>['xcrun', 'booted simulator'],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.stopRecording,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.io.recordVideo.stop',
            requires: <String>[
              'xcrun',
              'booted simulator',
              'active recording session',
            ],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.runShell,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.spawn',
            requires: <String>['xcrun', 'simulator device id'],
          ),
        ],
      );
    }
    return CockpitSystemControlProfile(
      platform: platform,
      deviceId: deviceId,
      appId: target.appId,
      processId: target.processId,
      adapter: 'ios.physical',
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.nativeUiPlane,
      ],
      recommendedNextStep: 'preferFlutterSemanticPlane',
      capabilities: const <CockpitSystemControlCapability>[
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.tap,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.webdriveragent',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.dismissSystemDialog,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.springboard',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.captureScreenshot,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-capture',
          requires: <String>['developer signing and device capture tooling'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.startRecording,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-recording',
          requires: <String>['developer signing and device capture tooling'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.stopRecording,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-recording.stop',
          requires: <String>[
            'developer signing and active device capture tooling',
          ],
        ),
      ],
    );
  }

  @override
  CockpitResolvedSystemControlCommand resolveCommand(
    CockpitSystemControlActionRequest request,
  ) {
    final deviceId = request.deviceId;
    if (deviceId == null || deviceId.isEmpty) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingDeviceId',
        message: 'iOS simulator system actions require --device-id.',
      );
    }
    return switch (request.action) {
      CockpitSystemControlAction.openUrl => cockpitTextCommand(
        request,
        'url',
        (url) => CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'openurl',
          deviceId,
          url,
        ]),
      ),
      CockpitSystemControlAction.captureScreenshot => cockpitTextCommand(
        request,
        'outputPath',
        (outputPath) => CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'io',
          deviceId,
          'screenshot',
          outputPath,
        ]),
      ),
      CockpitSystemControlAction.startRecording ||
      CockpitSystemControlAction.stopRecording =>
        const CockpitResolvedSystemControlCommand.error(
          code: 'systemEvidenceAction',
          message: 'Recording actions are executed through recording adapters.',
        ),
      CockpitSystemControlAction.runShell => cockpitShellCommand(
        request,
        (command) => CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'spawn',
          deviceId,
          ...command,
        ]),
      ),
      _ => const CockpitResolvedSystemControlCommand.error(
        code: 'systemActionBlocked',
        message: 'This iOS action requires XCTest/WebDriverAgent.',
      ),
    };
  }

  bool _looksLikeIosSimulatorDeviceId(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) {
      return false;
    }
    return RegExp(
      r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
    ).hasMatch(deviceId);
  }
}
