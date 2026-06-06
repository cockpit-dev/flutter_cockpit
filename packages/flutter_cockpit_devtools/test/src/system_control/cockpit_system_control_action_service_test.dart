import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_process_manager.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/adapters/cockpit_capture_adapter.dart';
import 'package:flutter_cockpit_devtools/src/adapters/cockpit_recording_adapter.dart';
import 'package:flutter_cockpit_devtools/src/system_control/cockpit_system_control_action_service.dart';
import 'package:test/test.dart';

void main() {
  test('android tap executes through adb shell input tap', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.tap,
        parameters: <String, Object?>{'x': 42, 'y': 88},
      ),
    );

    expect(result.success, isTrue);
    expect(result.availability, CockpitSystemControlAvailability.available);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'tap',
      '42',
      '88',
    ]);
    expect(processManager.starts.single.executable, 'adb');
    expect(processManager.starts.single.arguments, <String>[
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'tap',
      '42',
      '88',
    ]);
  });

  test(
    'blocked ios physical action returns guidance without spawning process',
    () async {
      final processManager = _FakeProcessManager();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'ios',
          deviceId: '00008110-001234',
          action: CockpitSystemControlAction.tap,
          parameters: <String, Object?>{'x': 42, 'y': 88},
        ),
      );

      expect(result.success, isFalse);
      expect(result.availability, CockpitSystemControlAvailability.blocked);
      expect(result.recommendedNextStep, 'preferFlutterSemanticPlane');
      expect(
        result.requires,
        contains('developer-signed XCTest/WebDriverAgent runner'),
      );
      expect(processManager.starts, isEmpty);
    },
  );

  test('missing required parameters fail before spawning process', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.tap,
      ),
    );

    expect(result.success, isFalse);
    expect(result.availability, CockpitSystemControlAvailability.available);
    expect(result.errorCode, 'missingSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('fractional integer parameters fail before spawning process', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.tap,
        parameters: <String, Object?>{'x': 42.7, 'y': 88},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('non-string text parameters fail before spawning process', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.pressKey,
        parameters: <String, Object?>{'key': 13},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('android grantPermission rejects non-string permission', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.grantPermission,
        parameters: <String, Object?>{'permission': 42},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('android setOrientation rejects non-string orientation', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.setOrientation,
        parameters: <String, Object?>{'orientation': 1},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('android package aliases reject non-string values', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.activateWindow,
        parameters: <String, Object?>{'packageId': 123},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('ios app aliases reject non-string values', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.activateWindow,
        parameters: <String, Object?>{'appId': 123},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('fractional longPress duration fails before spawning process', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.longPress,
        parameters: <String, Object?>{'x': 42, 'y': 88, 'durationMs': 1.5},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('non-positive drag duration fails before spawning process', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.drag,
        parameters: <String, Object?>{
          'startX': 10,
          'startY': 20,
          'endX': 30,
          'endY': 40,
          'durationMs': 0,
        },
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test(
    'invalid optional integer parameters do not fall back to defaults',
    () async {
      final processManager = _FakeProcessManager();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'macos',
          appId: 'dev.cockpit.example',
          action: CockpitSystemControlAction.readUiTree,
          parameters: <String, Object?>{'maxDepth': 'deep', 'maxNodes': 20},
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'invalidSystemActionParameter');
      expect(result.recommendedNextStep, 'fixActionPayload');
      expect(processManager.starts, isEmpty);
    },
  );

  test('readUiTree enforces positive integer limits', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'windows',
        processId: 4242,
        action: CockpitSystemControlAction.readUiTree,
        parameters: <String, Object?>{'maxDepth': 0, 'maxNodes': 20},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('ios status bar rejects invalid integer overrides', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.setStatusBar,
        parameters: <String, Object?>{'time': '09:41', 'wifiBars': 1.5},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('ios grantPermission rejects unsupported privacy services', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.grantPermission,
        parameters: <String, Object?>{'permission': 'camera'},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('ios setContentSize rejects unsupported categories', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.setContentSize,
        parameters: <String, Object?>{'contentSize': 'huge'},
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('ios status bar rejects unsupported string overrides', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.setStatusBar,
        parameters: <String, Object?>{
          'time': '09:41',
          'dataNetwork': 'bluetooth',
        },
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'invalidSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('android readUiTree cats a dumped XML tree', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.readUiTree,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'sh',
      '-c',
      'uiautomator dump /sdcard/window.xml >/dev/null && cat /sdcard/window.xml && rm /sdcard/window.xml',
    ]);
  });

  test('android activateWindow launches package through adb monkey', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.activateWindow,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'monkey',
      '-p',
      'dev.cockpit.example',
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]);
  });

  test('android grantPermission accepts appId as the package id', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.grantPermission,
        parameters: <String, Object?>{
          'permission': 'android.permission.CAMERA',
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'pm',
      'grant',
      'dev.cockpit.example',
      'android.permission.CAMERA',
    ]);
  });

  test('android pressKey sends adb keyevent', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.pressKey,
        parameters: <String, Object?>{'key': 'KEYCODE_ENTER'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'keyevent',
      'KEYCODE_ENTER',
    ]);
  });

  test('android terminateApp force-stops the package', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.terminateApp,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'am',
      'force-stop',
      'dev.cockpit.example',
    ]);
  });

  test(
    'android setAppearance maps dark mode to UiModeManager night yes',
    () async {
      final processManager = _FakeProcessManager();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.setAppearance,
          parameters: <String, Object?>{'appearance': 'dark'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.command, <String>[
        'adb',
        '-s',
        'emulator-5554',
        'shell',
        'cmd',
        'uimode',
        'night',
        'yes',
      ]);
    },
  );

  test('android setContentSize maps content token to font scale', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.setContentSize,
        parameters: <String, Object?>{'contentSize': 'accessibility-large'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'settings',
      'put',
      'system',
      'font_scale',
      '1.8',
    ]);
  });

  test('android setLocation sends emulator geo fix in lon lat order', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.setLocation,
        parameters: <String, Object?>{
          'latitude': 37.3349,
          'longitude': -122.009,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'emu',
      'geo',
      'fix',
      '-122.009',
      '37.3349',
    ]);
  });

  test('android setOrientation locks device rotation', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.setOrientation,
        parameters: <String, Object?>{'orientation': 'landscape'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'sh',
      '-c',
      'settings put system accelerometer_rotation 0 && settings put system user_rotation 1',
    ]);
  });

  test('android setNetworkSpeed uses the emulator console', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.setNetworkSpeed,
        parameters: <String, Object?>{'networkSpeed': 'full'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'emu',
      'network',
      'speed',
      'full',
    ]);
  });

  test('android setNetworkDelay uses the emulator console', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.setNetworkDelay,
        parameters: <String, Object?>{'networkDelay': 'none'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'emu',
      'network',
      'delay',
      'none',
    ]);
  });

  test('android readProcessList uses adb ps', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.readProcessList,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'ps',
      '-A',
    ]);
  });

  test('ios simulator activateWindow launches app through simctl', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.activateWindow,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'launch',
      '--terminate-running-process',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'dev.cockpit.example',
    ]);
  });

  test('ios simulator grantPermission uses simctl privacy grant', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.grantPermission,
        parameters: <String, Object?>{'permission': 'photos'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'privacy',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'grant',
      'photos',
      'dev.cockpit.example',
    ]);
  });

  test('ios simulator readSystemState lists device JSON', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.readSystemState,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'list',
      '-j',
      'devices',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
    ]);
  });

  test('ios simulator setClipboard writes through simctl pbcopy', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.setClipboard,
        parameters: <String, Object?>{'text': 'hello clipboard'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'sh',
      '-c',
      r'printf "%s" "$2" | xcrun simctl pbcopy "$1"',
      'flutter_cockpit_ios_clipboard',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'hello clipboard',
    ]);
  });

  test('ios simulator getClipboard reads through simctl pbpaste', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.getClipboard,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'pbpaste',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
    ]);
  });

  test('ios simulator terminateApp uses simctl terminate', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.terminateApp,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'terminate',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'dev.cockpit.example',
    ]);
  });

  test('ios simulator setAppearance uses simctl ui appearance', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.setAppearance,
        parameters: <String, Object?>{'appearance': 'dark'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'ui',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'appearance',
      'dark',
    ]);
  });

  test('ios simulator setContentSize uses simctl ui content_size', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.setContentSize,
        parameters: <String, Object?>{'contentSize': 'accessibility-large'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'ui',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'content_size',
      'accessibility-large',
    ]);
  });

  test('ios simulator setLocation uses simctl location set', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.setLocation,
        parameters: <String, Object?>{
          'latitude': 37.3349,
          'longitude': -122.009,
        },
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'location',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'set',
      '37.3349,-122.009',
    ]);
  });

  test(
    'ios simulator setStatusBar overrides deterministic status data',
    () async {
      final processManager = _FakeProcessManager();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'ios',
          deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
          action: CockpitSystemControlAction.setStatusBar,
          parameters: <String, Object?>{
            'time': '09:41',
            'dataNetwork': 'wifi',
            'wifiMode': 'active',
            'wifiBars': 3,
            'batteryState': 'charged',
            'batteryLevel': 100,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.command, <String>[
        'xcrun',
        'simctl',
        'status_bar',
        '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        'override',
        '--time',
        '09:41',
        '--dataNetwork',
        'wifi',
        '--wifiMode',
        'active',
        '--wifiBars',
        '3',
        '--batteryState',
        'charged',
        '--batteryLevel',
        '100',
      ]);
    },
  );

  test('ios simulator clearStatusBar clears status overrides', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.clearStatusBar,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'status_bar',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'clear',
    ]);
  });

  test('ios simulator readProcessList uses simctl spawn /bin/ps', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        action: CockpitSystemControlAction.readProcessList,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'xcrun',
      'simctl',
      'spawn',
      '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      '/bin/ps',
      '-A',
    ]);
  });

  test('macos setClipboard writes through pbcopy without app target', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'macos',
        action: CockpitSystemControlAction.setClipboard,
        parameters: <String, Object?>{'text': 'hello clipboard'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'sh',
      '-c',
      r'printf "%s" "$1" | pbcopy',
      'flutter_cockpit_macos_clipboard',
      'hello clipboard',
    ]);
  });

  test('macos readUiTree uses bounded System Events tree dump', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'macos',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.readUiTree,
        parameters: <String, Object?>{'maxDepth': 2, 'maxNodes': 20},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command[0], 'osascript');
    expect(
      result.command,
      containsAllInOrder(<String>['-l', 'JavaScript', '-e']),
    );
    expect(result.command.sublist(result.command.length - 4), <String>[
      'appId',
      'dev.cockpit.example',
      '2',
      '20',
    ]);
  });

  test('macos readProcessList uses ps', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'macos',
        action: CockpitSystemControlAction.readProcessList,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>['ps', '-axo', 'pid=,ppid=,comm=']);
  });

  test('macos readWindows uses a bounded System Events window list', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'macos',
        action: CockpitSystemControlAction.readWindows,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command[0], 'osascript');
    expect(
      result.command,
      containsAllInOrder(<String>['-l', 'JavaScript', '-e']),
    );
  });

  test('windows readUiTree uses bounded UI Automation tree dump', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'windows',
        processId: 4242,
        action: CockpitSystemControlAction.readUiTree,
        parameters: <String, Object?>{'maxDepth': 3, 'maxNodes': 30},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command[0], 'powershell');
    expect(result.command, contains('-NoProfile'));
    expect(result.command, contains('-NonInteractive'));
    expect(result.command.sublist(result.command.length - 4), <String>[
      'processId',
      '4242',
      '3',
      '30',
    ]);
  });

  test('windows readWindows uses visible process windows', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'windows',
        action: CockpitSystemControlAction.readWindows,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command[0], 'powershell');
    expect(result.command, contains('-NoProfile'));
    expect(result.command, contains('-NonInteractive'));
    expect(result.command.last, contains('MainWindowTitle'));
  });

  test('linux pressKey targets a window with xdotool key', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'linux',
        appId: 'dev.cockpit.example',
        action: CockpitSystemControlAction.pressKey,
        parameters: <String, Object?>{'key': 'Escape'},
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, hasLength(8));
    expect(result.command[0], 'sh');
    expect(result.command[1], '-c');
    expect(
      result.command[2],
      contains(r'exec xdotool windowactivate --sync "$window_id" "$@"'),
    );
    expect(result.command.sublist(3), <String>[
      'flutter_cockpit_linux_input',
      'appId',
      'dev.cockpit.example',
      'key',
      'Escape',
    ]);
  });

  test('linux readWindows uses wmctrl or xdotool fallback', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'linux',
        action: CockpitSystemControlAction.readWindows,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command[0], 'sh');
    expect(result.command[1], '-c');
    expect(result.command[2], contains('wmctrl -lp'));
    expect(result.command[2], contains('xdotool search --onlyvisible'));
  });

  test('timed out command returns structured action failure', () async {
    final service = CockpitSystemControlActionService(
      processManager: _HangingProcessManager(),
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.tap,
        parameters: <String, Object?>{'x': 42, 'y': 88},
        timeout: Duration(milliseconds: 1),
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'systemActionTimedOut');
    expect(result.recommendedNextStep, 'inspectShellFailure');
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'tap',
      '42',
      '88',
    ]);
  });

  test('process startup failure returns structured action failure', () async {
    final service = CockpitSystemControlActionService(
      processManager: _ThrowingProcessManager(),
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.pressBack,
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'systemActionProcessFailed');
    expect(result.recommendedNextStep, 'inspectShellFailure');
    expect(result.errorMessage, contains('Unable to start process'));
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'keyevent',
      'KEYCODE_BACK',
    ]);
  });

  test(
    'captureScreenshot copies adapter artifact to requested output path',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_system_capture_test_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes(<int>[137, 80, 78, 71]);
      final outputFile = File('${tempDir.path}/copied.png');
      final processManager = _FakeProcessManager();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
        captureAdapterFactory: (_) => _FakeCaptureAdapter(sourceFile),
      );

      final result = await service.run(
        CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.captureScreenshot,
          parameters: <String, Object?>{
            'name': 'acceptance',
            'outputPath': outputFile.path,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.sourceFilePath, outputFile.path);
      expect(result.artifact?['relativePath'], 'screenshots/acceptance.png');
      expect(await outputFile.readAsBytes(), <int>[137, 80, 78, 71]);
      expect(processManager.starts, isEmpty);
    },
  );

  test('captureScreenshot adapter failure returns structured result', () async {
    final service = CockpitSystemControlActionService(
      captureAdapterFactory: (_) => const _FailingCaptureAdapter(),
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.captureScreenshot,
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'systemCaptureFailed');
    expect(result.recommendedNextStep, 'inspectCaptureFailure');
    expect(result.errorMessage, contains('capture permission denied'));
  });

  test(
    'captureScreenshot fails when an adapter reports success without a source file',
    () async {
      final service = CockpitSystemControlActionService(
        captureAdapterFactory: (_) => const _MissingArtifactCaptureAdapter(),
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.captureScreenshot,
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'systemCaptureMissingArtifact');
      expect(result.recommendedNextStep, 'inspectCaptureFailure');
    },
  );

  test(
    'startRecording starts adapter session without spawning process',
    () async {
      final processManager = _FakeProcessManager();
      final recordingAdapter = _FakeRecordingAdapter();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
        recordingAdapterFactory: (_) => recordingAdapter,
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.startRecording,
          parameters: <String, Object?>{'name': 'flow', 'purpose': 'repro'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.recommendedNextStep, 'runFlowThenStopRecording');
      expect(result.recordingSession?['state'], 'recording');
      expect(recordingAdapter.startedRequest?.name, 'flow');
      expect(
        recordingAdapter.startedRequest?.purpose,
        CockpitRecordingPurpose.repro,
      );
      expect(processManager.starts, isEmpty);
    },
  );

  test('stopRecording returns completed adapter artifact', () async {
    final processManager = _FakeProcessManager();
    final recordingAdapter = _FakeRecordingAdapter();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
      recordingAdapterFactory: (_) => recordingAdapter,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.stopRecording,
      ),
    );

    expect(result.success, isTrue);
    expect(result.sourceFilePath, '/tmp/system-recording.mp4');
    expect(result.artifact?['relativePath'], 'recordings/system-recording.mp4');
    expect(result.recordingResult?['state'], 'completed');
    expect(processManager.starts, isEmpty);
  });

  test(
    'stopRecording copies completed video to requested output path',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_system_recording_output_test_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourceFile = File('${tempDir.path}/source.mp4');
      await sourceFile.writeAsBytes(<int>[0, 0, 0, 24, 102, 116, 121, 112]);
      final outputFile = File('${tempDir.path}/copied.mp4');
      final service = CockpitSystemControlActionService(
        recordingAdapterFactory: (_) =>
            _FakeRecordingAdapter(sourceFilePath: sourceFile.path),
      );

      final result = await service.run(
        CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.stopRecording,
          parameters: <String, Object?>{'outputPath': outputFile.path},
        ),
      );

      expect(result.success, isTrue);
      expect(result.sourceFilePath, outputFile.path);
      expect(result.recordingResult?['sourceFilePath'], outputFile.path);
      expect(await outputFile.readAsBytes(), <int>[
        0,
        0,
        0,
        24,
        102,
        116,
        121,
        112,
      ]);
    },
  );

  test(
    'stopRecording accepts an output path that already is the source path',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_system_recording_same_output_test_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourceFile = File('${tempDir.path}/source.mp4');
      await sourceFile.writeAsBytes(<int>[0, 0, 0, 24, 102, 116, 116, 121]);
      final service = CockpitSystemControlActionService(
        recordingAdapterFactory: (_) =>
            _FakeRecordingAdapter(sourceFilePath: sourceFile.path),
      );

      final result = await service.run(
        CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.stopRecording,
          parameters: <String, Object?>{'outputPath': sourceFile.path},
        ),
      );

      expect(result.success, isTrue);
      expect(result.sourceFilePath, sourceFile.path);
      expect(await sourceFile.readAsBytes(), <int>[
        0,
        0,
        0,
        24,
        102,
        116,
        116,
        121,
      ]);
    },
  );

  test(
    'stopRecording fails when an adapter reports completion without a source file',
    () async {
      final service = CockpitSystemControlActionService(
        recordingAdapterFactory: (_) =>
            _FakeRecordingAdapter(sourceFilePath: null),
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.stopRecording,
        ),
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'systemRecordingMissingArtifact');
      expect(result.recommendedNextStep, 'inspectRecordingFailure');
      expect(result.recordingResult?['state'], 'completed');
    },
  );

  test('stopRecording adapter failure returns structured result', () async {
    final service = CockpitSystemControlActionService(
      recordingAdapterFactory: (_) => const _FailingRecordingAdapter(),
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.stopRecording,
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'systemRecordingFailed');
    expect(result.recommendedNextStep, 'inspectRecordingFailure');
    expect(result.errorMessage, contains('No active recording session'));
  });
}

final class _FakeCaptureAdapter implements CockpitCaptureAdapter {
  const _FakeCaptureAdapter(this.sourceFile);

  final File sourceFile;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    final request = command.screenshotRequest!;
    final artifact = CockpitArtifactRef(
      role: 'screenshot',
      relativePath: 'screenshots/${request.name}.png',
    );
    return CockpitCommandExecution(
      result: CockpitCommandResult(
        success: true,
        commandId: command.commandId,
        commandType: command.commandType,
        durationMs: 12,
        artifacts: <CockpitArtifactRef>[artifact],
      ),
      artifactSourcePaths: <String, String>{
        artifact.relativePath: sourceFile.path,
      },
    );
  }
}

final class _FailingCaptureAdapter implements CockpitCaptureAdapter {
  const _FailingCaptureAdapter();

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) {
    throw StateError('capture permission denied');
  }
}

final class _MissingArtifactCaptureAdapter implements CockpitCaptureAdapter {
  const _MissingArtifactCaptureAdapter();

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    return CockpitCommandExecution(
      result: CockpitCommandResult(
        success: true,
        commandId: command.commandId,
        commandType: command.commandType,
        durationMs: 12,
      ),
    );
  }
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  _FakeRecordingAdapter({this.sourceFilePath = '/tmp/system-recording.mp4'});

  final String? sourceFilePath;
  CockpitRecordingRequest? startedRequest;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    startedRequest = request;
    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    return CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      purpose: CockpitRecordingPurpose.acceptance,
      recordingKind: CockpitRecordingKind.nativeScreen,
      effectiveLayer: CockpitRecordingLayer.system,
      artifact: const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/system-recording.mp4',
      ),
      durationMs: 1200,
      sourceFilePath: sourceFilePath,
    );
  }
}

final class _FailingRecordingAdapter implements CockpitRecordingAdapter {
  const _FailingRecordingAdapter();

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    throw StateError('Recording could not start.');
  }

  @override
  Future<CockpitRecordingResult> stopRecording() {
    throw StateError('No active recording session exists.');
  }
}

final class _FakeProcessManager implements CockpitProcessManager {
  final starts = <_StartedProcess>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    starts.add(
      _StartedProcess(
        executable: executable,
        arguments: List<String>.unmodifiable(arguments),
      ),
    );
    return _FakeManagedProcess();
  }
}

final class _StartedProcess {
  const _StartedProcess({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}

final class _HangingProcessManager implements CockpitProcessManager {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    return _HangingManagedProcess();
  }
}

final class _ThrowingProcessManager implements CockpitProcessManager {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    throw ProcessException(executable, arguments, 'Unable to start process');
  }
}

final class _FakeManagedProcess implements Process {
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode async => 0;

  @override
  int get pid => 1234;

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _stdinController.close();
    return true;
  }
}

final class _HangingManagedProcess implements Process {
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  final Completer<int> _exitCode = Completer<int>();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  int get pid => 5678;

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exitCode.isCompleted) {
      _exitCode.complete(-9);
    }
    _stdinController.close();
    return true;
  }
}
