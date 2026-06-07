import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cockpit_system_control_action.dart';
import '../cockpit_system_control_adapter.dart';
import '../cockpit_system_control_parameters.dart';
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
        capabilities: <CockpitSystemControlCapability>[
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.tap,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.webdriveragent',
            requires: <String>[
              'booted simulator',
              'XCTest/WebDriverAgent runner',
            ],
            parameters: CockpitSystemControlParameterSets.coordinate,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.longPress,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.webdriveragent',
            requires: <String>[
              'booted simulator',
              'XCTest/WebDriverAgent runner',
            ],
            parameters: CockpitSystemControlParameterSets.longPress,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.drag,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.webdriveragent',
            requires: <String>[
              'booted simulator',
              'XCTest/WebDriverAgent runner',
            ],
            parameters: CockpitSystemControlParameterSets.drag,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.typeText,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.webdriveragent',
            requires: <String>[
              'booted simulator',
              'XCTest/WebDriverAgent runner',
            ],
            parameters: CockpitSystemControlParameterSets.text,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.pressKey,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.webdriveragent.key',
            requires: <String>[
              'booted simulator',
              'XCTest/WebDriverAgent runner',
            ],
            parameters: CockpitSystemControlParameterSets.key,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.pressBack,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.unsupported,
            strategy: 'ios-no-global-back-key',
            limitations: <String>[
              'iOS has no stable app-scoped Back key outside app UI semantics.',
            ],
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.pressHome,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.unsupported,
            strategy: 'simctl-no-home-key',
            limitations: <String>[
              'simctl does not expose a stable Home button action.',
            ],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.activateWindow,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.launch',
            requires: <String>['xcrun', 'simulator device id', 'app id'],
            parameters: CockpitSystemControlParameterSets.iosApp,
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.terminateApp,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.terminate',
            requires: <String>['xcrun', 'simulator device id', 'app id'],
            parameters: CockpitSystemControlParameterSets.iosApp,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.dismissSystemDialog,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.springboard',
            requires: <String>['XCTest/WebDriverAgent runner'],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.grantPermission,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.privacy.grant',
            requires: <String>[
              'xcrun',
              'simulator device id',
              'privacy service',
              'app id',
            ],
            parameters: CockpitSystemControlParameterSets.iosGrantPermission,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.openUrl,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.openurl',
            requires: <String>['xcrun', 'simulator device id'],
            parameters: CockpitSystemControlParameterSets.url,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.setAppearance,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.ui.appearance',
            requires: <String>[
              'xcrun',
              'simulator device id',
              'appearance mode',
            ],
            parameters: CockpitSystemControlParameterSets.iosAppearance,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.setContentSize,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.ui.content_size',
            requires: <String>[
              'xcrun',
              'simulator device id',
              'content size category',
            ],
            parameters: CockpitSystemControlParameterSets.iosContentSize,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.setLocation,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.location.set',
            requires: <String>[
              'xcrun',
              'simulator device id',
              'latitude',
              'longitude',
            ],
            parameters: CockpitSystemControlParameterSets.location,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.setOrientation,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.device.orientation',
            requires: <String>['XCTest/WebDriverAgent runner'],
            parameters: CockpitSystemControlParameterSets.iosOrientation,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.setNetworkSpeed,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'network-link-conditioner-or-host-proxy',
            requires: <String>[
              'Network Link Conditioner or host proxy tooling',
            ],
            limitations: <String>[
              'simctl status_bar can change network icons but not real network transport.',
            ],
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.setNetworkDelay,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'network-link-conditioner-or-host-proxy',
            requires: <String>[
              'Network Link Conditioner or host proxy tooling',
            ],
            limitations: <String>[
              'simctl status_bar can change network icons but not real network transport.',
            ],
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.setStatusBar,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.status_bar.override',
            requires: <String>['xcrun', 'simulator device id'],
            parameters: CockpitSystemControlParameterSets.iosStatusBar,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.clearStatusBar,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.status_bar.clear',
            requires: <String>['xcrun', 'simulator device id'],
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.setClipboard,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.pbcopy',
            requires: <String>['xcrun', 'simulator device id'],
            parameters: CockpitSystemControlParameterSets.text,
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.getClipboard,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.pbpaste',
            requires: <String>['xcrun', 'simulator device id'],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.captureScreenshot,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.io.screenshot',
            requires: <String>['xcrun', 'booted simulator'],
            parameters: CockpitSystemControlParameterSets.screenshot,
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.startRecording,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.io.recordVideo',
            requires: <String>['xcrun', 'booted simulator'],
            parameters: CockpitSystemControlParameterSets.startRecording,
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
            parameters: CockpitSystemControlParameterSets.stopRecording,
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.readUiTree,
            plane: CockpitPlaneKind.nativeUiPlane,
            availability: CockpitSystemControlAvailability.blocked,
            strategy: 'xctest.webdriveragent.tree',
            requires: <String>['XCTest/WebDriverAgent runner'],
            parameters: CockpitSystemControlParameterSets.readUiTree,
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.readProcessList,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.spawn.bin-ps',
            requires: <String>['xcrun', 'simulator device id'],
          ),
          const CockpitSystemControlCapability(
            action: CockpitSystemControlAction.readWindows,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.unsupported,
            strategy: 'ios-no-window-manager',
            limitations: <String>[
              'iOS simulator does not expose app windows through a stable simctl API.',
            ],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.readSystemState,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.list.devices',
            requires: <String>['xcrun', 'simulator device id'],
          ),
          CockpitSystemControlCapability(
            action: CockpitSystemControlAction.runShell,
            plane: CockpitPlaneKind.deviceSystemPlane,
            availability: CockpitSystemControlAvailability.available,
            strategy: 'xcrun.simctl.spawn',
            requires: <String>['xcrun', 'simulator device id'],
            parameters: CockpitSystemControlParameterSets.shellCommand,
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
          parameters: CockpitSystemControlParameterSets.coordinate,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.longPress,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.webdriveragent',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
          parameters: CockpitSystemControlParameterSets.longPress,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.drag,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.webdriveragent',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
          parameters: CockpitSystemControlParameterSets.drag,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.typeText,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.webdriveragent',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
          parameters: CockpitSystemControlParameterSets.text,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressKey,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.webdriveragent.key',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
          parameters: CockpitSystemControlParameterSets.key,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressBack,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.unsupported,
          strategy: 'ios-no-global-back-key',
          limitations: <String>[
            'iOS has no stable app-scoped Back key outside app UI semantics.',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressHome,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.device.home',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.activateWindow,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-launch',
          requires: <String>['developer signing and device launch tooling'],
          parameters: CockpitSystemControlParameterSets.iosApp,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.terminateApp,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-terminate',
          requires: <String>['developer signing and device process tooling'],
          parameters: CockpitSystemControlParameterSets.iosApp,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.dismissSystemDialog,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.springboard',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.grantPermission,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-permission-flow',
          requires: <String>[
            'developer signing and app-specific permission flow',
          ],
          parameters: CockpitSystemControlParameterSets.iosGrantPermission,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.openUrl,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-open-url',
          requires: <String>['developer signing and device URL tooling'],
          parameters: CockpitSystemControlParameterSets.url,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setAppearance,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-appearance',
          requires: <String>['developer signing and device appearance tooling'],
          parameters: CockpitSystemControlParameterSets.iosAppearance,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setContentSize,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-content-size',
          requires: <String>[
            'developer signing and device accessibility tooling',
          ],
          parameters: CockpitSystemControlParameterSets.iosContentSize,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setLocation,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-location',
          requires: <String>[
            'developer signing and location simulation tooling',
          ],
          parameters: CockpitSystemControlParameterSets.location,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setOrientation,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.device.orientation',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
          parameters: CockpitSystemControlParameterSets.iosOrientation,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setNetworkSpeed,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-network-conditioning',
          requires: <String>[
            'developer signing and network conditioning tooling',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setNetworkDelay,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-network-conditioning',
          requires: <String>[
            'developer signing and network conditioning tooling',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setStatusBar,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-status-bar',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
          parameters: CockpitSystemControlParameterSets.iosStatusBar,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.clearStatusBar,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-status-bar.clear',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setClipboard,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-pasteboard',
          requires: <String>['developer signing and device pasteboard tooling'],
          parameters: CockpitSystemControlParameterSets.text,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.getClipboard,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-pasteboard',
          requires: <String>['developer signing and device pasteboard tooling'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.captureScreenshot,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-capture',
          requires: <String>['developer signing and device capture tooling'],
          parameters: CockpitSystemControlParameterSets.screenshot,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.startRecording,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-recording',
          requires: <String>['developer signing and device capture tooling'],
          parameters: CockpitSystemControlParameterSets.startRecording,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.stopRecording,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-recording.stop',
          requires: <String>[
            'developer signing and active device capture tooling',
          ],
          parameters: CockpitSystemControlParameterSets.stopRecording,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readUiTree,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'xctest.webdriveragent.tree',
          requires: <String>['developer-signed XCTest/WebDriverAgent runner'],
          parameters: CockpitSystemControlParameterSets.readUiTree,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readProcessList,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-process-list',
          requires: <String>[
            'developer signing and device diagnostics tooling',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readWindows,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.unsupported,
          strategy: 'ios-no-window-manager',
          limitations: <String>[
            'iOS does not expose app windows through a stable public device API.',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readSystemState,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'developer-device-diagnostics',
          requires: <String>[
            'developer signing and device diagnostics tooling',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.runShell,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.unsupported,
          strategy: 'ios-no-device-shell',
          limitations: <String>[
            'iOS does not expose a general public device shell.',
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
    if (!_looksLikeIosSimulatorDeviceId(deviceId)) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'systemActionBlocked',
        message:
            'This iOS physical-device action requires XCTest/WebDriverAgent or developer device tooling.',
      );
    }
    return switch (request.action) {
      CockpitSystemControlAction.activateWindow => _appScopedCommand(
        request,
        (appId) => CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'launch',
          '--terminate-running-process',
          deviceId,
          appId,
        ]),
      ),
      CockpitSystemControlAction.terminateApp => _appScopedCommand(
        request,
        (appId) => CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'terminate',
          deviceId,
          appId,
        ]),
      ),
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
      CockpitSystemControlAction.setAppearance => cockpitTextCommand(
        request,
        'appearance',
        (appearance) => _iosSetAppearanceCommand(
          appearance,
          (mode) => CockpitResolvedSystemControlCommand('xcrun', <String>[
            'simctl',
            'ui',
            deviceId,
            'appearance',
            mode,
          ]),
        ),
        trim: true,
        allowedValues: const <String>['light', 'dark'],
      ),
      CockpitSystemControlAction.setContentSize => cockpitTextCommand(
        request,
        'contentSize',
        (contentSize) => CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'ui',
          deviceId,
          'content_size',
          contentSize,
        ]),
        trim: true,
        allowedValues:
            CockpitSystemControlAllowedValues.iosContentSizeCategories,
      ),
      CockpitSystemControlAction.setLocation => cockpitLocationCommand(
        request,
        (latitude, longitude, altitude) {
          return CockpitResolvedSystemControlCommand('xcrun', <String>[
            'simctl',
            'location',
            deviceId,
            'set',
            '${_formatCoordinate(latitude)},${_formatCoordinate(longitude)}',
          ]);
        },
      ),
      CockpitSystemControlAction.setStatusBar => _iosSetStatusBarCommand(
        request,
        (args) => CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'status_bar',
          deviceId,
          'override',
          ...args,
        ]),
      ),
      CockpitSystemControlAction.clearStatusBar =>
        CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'status_bar',
          deviceId,
          'clear',
        ]),
      CockpitSystemControlAction.setClipboard => cockpitTextCommand(
        request,
        'text',
        (text) => CockpitResolvedSystemControlCommand('sh', <String>[
          '-c',
          r'printf "%s" "$2" | xcrun simctl pbcopy "$1"',
          'flutter_cockpit_ios_clipboard',
          deviceId,
          text,
        ]),
      ),
      CockpitSystemControlAction.getClipboard =>
        CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'pbpaste',
          deviceId,
        ]),
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
      CockpitSystemControlAction.grantPermission => _permissionCommand(
        request,
        (appId, service) => CockpitResolvedSystemControlCommand(
          'xcrun',
          <String>['simctl', 'privacy', deviceId, 'grant', service, appId],
        ),
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
      CockpitSystemControlAction.readProcessList =>
        CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'spawn',
          deviceId,
          '/bin/ps',
          '-A',
        ]),
      CockpitSystemControlAction.readSystemState =>
        CockpitResolvedSystemControlCommand('xcrun', <String>[
          'simctl',
          'list',
          '-j',
          'devices',
          deviceId,
        ]),
      _ => const CockpitResolvedSystemControlCommand.error(
        code: 'systemActionBlocked',
        message: 'This iOS action requires XCTest/WebDriverAgent.',
      ),
    };
  }

  CockpitResolvedSystemControlCommand _appScopedCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(String appId) factory,
  ) {
    final appId = _readAppId(request);
    if (appId.isInvalid) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: '${request.action.name} requires a string appId.',
      );
    }
    if (!appId.isValid) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: '${request.action.name} requires --app-id or appId.',
      );
    }
    return factory(appId.value!);
  }

  CockpitResolvedSystemControlCommand _permissionCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(String appId, String service)
    factory,
  ) {
    final appId = _readAppId(request);
    if (appId.isInvalid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: 'grantPermission requires a string appId.',
      );
    }
    if (!appId.isValid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: 'grantPermission requires --app-id or appId.',
      );
    }
    final service = cockpitReadSystemControlStringParameter(
      request.parameters,
      'permission',
      allowedValues: CockpitSystemControlAllowedValues.iosPrivacyServices,
    );
    if (service.isInvalid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message:
            'grantPermission requires a valid iOS simulator privacy service.',
      );
    }
    if (!service.isValid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: 'grantPermission requires a permission or service parameter.',
      );
    }
    return factory(appId.value!, service.value!);
  }

  CockpitResolvedSystemControlCommand _iosSetStatusBarCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(List<String> args) factory,
  ) {
    final args = <String>[];
    String? errorMessage;
    void addString(
      String parameterName,
      String flagName, {
      List<String> allowedValues = const <String>[],
    }) {
      final value = cockpitReadSystemControlStringParameter(
        request.parameters,
        parameterName,
        allowedValues: allowedValues,
      );
      if (!value.isPresent) {
        return;
      }
      if (value.isInvalid) {
        errorMessage = '$parameterName has an unsupported value.';
        return;
      }
      args.addAll(<String>['--$flagName', value.value!]);
    }

    void addInt(String parameterName, String flagName, int min, int max) {
      final value = cockpitReadSystemControlIntParameter(
        request.parameters,
        parameterName,
        minimum: min,
        maximum: max,
      );
      if (!value.isPresent) {
        return;
      }
      if (value.isInvalid) {
        errorMessage =
            '$parameterName must be an integer between $min and $max.';
        return;
      }
      args.addAll(<String>['--$flagName', '${value.value}']);
    }

    addString('time', 'time');
    addString(
      'dataNetwork',
      'dataNetwork',
      allowedValues: CockpitSystemControlAllowedValues.iosStatusBarDataNetworks,
    );
    addString(
      'wifiMode',
      'wifiMode',
      allowedValues: CockpitSystemControlAllowedValues.iosStatusBarWifiModes,
    );
    addInt('wifiBars', 'wifiBars', 0, 3);
    addString(
      'cellularMode',
      'cellularMode',
      allowedValues:
          CockpitSystemControlAllowedValues.iosStatusBarCellularModes,
    );
    addInt('cellularBars', 'cellularBars', 0, 4);
    addString('operatorName', 'operatorName');
    addString(
      'batteryState',
      'batteryState',
      allowedValues:
          CockpitSystemControlAllowedValues.iosStatusBarBatteryStates,
    );
    addInt('batteryLevel', 'batteryLevel', 0, 100);
    if (errorMessage != null) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: errorMessage!,
      );
    }
    if (args.isEmpty) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message:
            'setStatusBar requires at least one status bar parameter such as time, dataNetwork, wifiBars, or batteryLevel.',
      );
    }
    return factory(args);
  }

  CockpitSystemControlStringParameter _readAppId(
    CockpitSystemControlActionRequest request,
  ) {
    final appId = request.appId?.trim();
    if (appId != null && appId.isNotEmpty) {
      return CockpitSystemControlStringParameter.valid(appId);
    }
    return cockpitReadFirstSystemControlStringParameter(
      request.parameters,
      const <String>['appId'],
    );
  }

  CockpitResolvedSystemControlCommand _iosSetAppearanceCommand(
    String appearance,
    CockpitResolvedSystemControlCommand Function(String mode) factory,
  ) {
    final mode = switch (appearance.trim().toLowerCase()) {
      'dark' => 'dark',
      'light' => 'light',
      _ => null,
    };
    if (mode == null) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: 'setAppearance requires appearance light or dark on iOS.',
      );
    }
    return factory(mode);
  }

  String _formatCoordinate(double value) {
    final text = value.toStringAsFixed(6);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  bool _looksLikeIosSimulatorDeviceId(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) {
      return false;
    }
    if (deviceId == 'booted') {
      return true;
    }
    return RegExp(
      r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
    ).hasMatch(deviceId);
  }
}
