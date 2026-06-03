import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cockpit_system_control_action.dart';
import '../cockpit_system_control_adapter.dart';
import '../cockpit_system_control_profile.dart';

final class CockpitAndroidSystemControlAdapter
    implements CockpitSystemControlAdapter {
  const CockpitAndroidSystemControlAdapter();

  @override
  String get platform => 'android';

  @override
  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  ) {
    final hasDeviceId =
        target.deviceId != null && target.deviceId!.trim().isNotEmpty;
    final availability = hasDeviceId
        ? CockpitSystemControlAvailability.available
        : CockpitSystemControlAvailability.blocked;
    final isEmulator = (target.deviceId ?? '').startsWith('emulator-');
    final emulatorAvailability = isEmulator
        ? CockpitSystemControlAvailability.available
        : CockpitSystemControlAvailability.blocked;
    return CockpitSystemControlProfile(
      platform: platform,
      deviceId: target.deviceId,
      appId: target.appId,
      processId: target.processId,
      adapter: 'android.adb',
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.nativeUiPlane,
        CockpitPlaneKind.deviceSystemPlane,
      ],
      recommendedNextStep: 'preferFlutterSemanticPlane',
      capabilities: <CockpitSystemControlCapability>[
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.tap,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.tap',
          requires: <String>['adb', 'device id'],
          limitations: <String>['coordinate input has no semantic locator'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.longPress,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.swipe.hold',
          requires: <String>['adb', 'device id'],
          limitations: <String>['coordinate input has no semantic locator'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.drag,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.swipe',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.typeText,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.text',
          requires: <String>['adb', 'device id'],
          limitations: <String>['text must be escaped for adb input'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressKey,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.keyevent',
          requires: <String>['adb', 'device id', 'key name'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressBack,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.keyevent.KEYCODE_BACK',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressHome,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.keyevent.KEYCODE_HOME',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.activateWindow,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.monkey.launcher',
          requires: <String>['adb', 'device id', 'package id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.terminateApp,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.am.force-stop',
          requires: <String>['adb', 'device id', 'package id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.dismissSystemDialog,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.uiautomator-or-keyevent',
          requires: <String>['adb', 'device id'],
          limitations: <String>['dialog text varies by Android version'],
          fallbackActions: <CockpitSystemControlAction>[
            CockpitSystemControlAction.pressBack,
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.grantPermission,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.pm.grant',
          requires: <String>['adb', 'package id', 'permission name'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.openUrl,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.am.start.VIEW',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setAppearance,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.cmd.uimode.night',
          requires: <String>['adb', 'device id', 'appearance mode'],
          limitations: <String>[
            'Uses Android UiModeManager night mode; OEM behavior can vary.',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setContentSize,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.settings.put.system.font_scale',
          requires: <String>['adb', 'device id', 'content size or font scale'],
          limitations: <String>[
            'Applies the system font scale and can affect all apps on the device.',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setLocation,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: emulatorAvailability,
          strategy: 'adb.emu.geo.fix',
          requires: <String>[
            'adb',
            'Android emulator id',
            'latitude',
            'longitude',
          ],
          limitations: <String>[
            'adb emu geo fix is emulator-only; physical devices require app-specific mock-location setup.',
          ],
        ),
        const CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setClipboard,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'android-clipboard-requires-app-or-api-specific-helper',
          requires: <String>[
            'app instrumentation or API-specific clipboard helper',
          ],
          limitations: <String>[
            'Android does not expose a stable adb clipboard command across supported API levels.',
          ],
        ),
        const CockpitSystemControlCapability(
          action: CockpitSystemControlAction.getClipboard,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'android-clipboard-requires-app-or-api-specific-helper',
          requires: <String>[
            'app instrumentation or API-specific clipboard helper',
          ],
          limitations: <String>[
            'Android does not expose a stable adb clipboard command across supported API levels.',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.captureScreenshot,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.exec-out.screencap',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.startRecording,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.screenrecord',
          requires: <String>['adb', 'device id'],
          limitations: <String>['Android screenrecord has duration limits'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.stopRecording,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.screenrecord.stop-and-pull',
          requires: <String>['adb', 'device id', 'active recording session'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readUiTree,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: availability,
          strategy: 'adb.shell.uiautomator.dump',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readSystemState,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.dumpsys',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.runShell,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell',
          requires: <String>['adb', 'device id'],
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
        message: 'Android system actions require --device-id.',
      );
    }

    List<String> adbShell(List<String> shellArgs) {
      return <String>['-s', deviceId, 'shell', ...shellArgs];
    }

    return switch (request.action) {
      CockpitSystemControlAction.tap => cockpitCoordinateCommand(
        request,
        (x, y) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>['input', 'tap', '$x', '$y']),
        ),
      ),
      CockpitSystemControlAction.longPress => cockpitCoordinateCommand(
        request,
        (x, y) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>[
            'input',
            'swipe',
            '$x',
            '$y',
            '$x',
            '$y',
            '${cockpitReadSystemControlInt(request.parameters, 'durationMs') ?? 800}',
          ]),
        ),
      ),
      CockpitSystemControlAction.drag => cockpitDragCommand(request, (
        startX,
        startY,
        endX,
        endY,
        durationMs,
      ) {
        return CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>[
            'input',
            'swipe',
            '$startX',
            '$startY',
            '$endX',
            '$endY',
            '$durationMs',
          ]),
        );
      }),
      CockpitSystemControlAction.typeText => cockpitTextCommand(
        request,
        'text',
        (text) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>['input', 'text', _escapeAdbText(text)]),
        ),
      ),
      CockpitSystemControlAction.pressKey => cockpitTextCommand(
        request,
        'key',
        (key) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>['input', 'keyevent', _normalizeAndroidKey(key)]),
        ),
      ),
      CockpitSystemControlAction.pressBack =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['input', 'keyevent', 'KEYCODE_BACK']),
        ),
      CockpitSystemControlAction.pressHome =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['input', 'keyevent', 'KEYCODE_HOME']),
        ),
      CockpitSystemControlAction.activateWindow => _packageCommand(
        request,
        (packageId) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>[
            'monkey',
            '-p',
            packageId,
            '-c',
            'android.intent.category.LAUNCHER',
            '1',
          ]),
        ),
      ),
      CockpitSystemControlAction.terminateApp => _packageCommand(
        request,
        (packageId) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>['am', 'force-stop', packageId]),
        ),
      ),
      CockpitSystemControlAction.openUrl => cockpitTextCommand(
        request,
        'url',
        (url) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>[
            'am',
            'start',
            '-a',
            'android.intent.action.VIEW',
            '-d',
            url,
          ]),
        ),
      ),
      CockpitSystemControlAction.setAppearance => cockpitTextCommand(
        request,
        'appearance',
        (appearance) => _androidSetAppearanceCommand(
          appearance,
          (mode) => CockpitResolvedSystemControlCommand(
            'adb',
            adbShell(<String>['cmd', 'uimode', 'night', mode]),
          ),
        ),
      ),
      CockpitSystemControlAction.setContentSize =>
        _androidSetContentSizeCommand(
          request,
          (fontScale) => CockpitResolvedSystemControlCommand(
            'adb',
            adbShell(<String>[
              'settings',
              'put',
              'system',
              'font_scale',
              fontScale,
            ]),
          ),
        ),
      CockpitSystemControlAction.setLocation => cockpitLocationCommand(request, (
        latitude,
        longitude,
        altitude,
      ) {
        if (!deviceId.startsWith('emulator-')) {
          return const CockpitResolvedSystemControlCommand.error(
            code: 'systemActionBlocked',
            message:
                'Android setLocation is available only for emulator-* device ids.',
          );
        }
        return CockpitResolvedSystemControlCommand('adb', <String>[
          '-s',
          deviceId,
          'emu',
          'geo',
          'fix',
          _formatCoordinate(longitude),
          _formatCoordinate(latitude),
          if (altitude != null) _formatCoordinate(altitude),
        ]);
      }),
      CockpitSystemControlAction.setClipboard ||
      CockpitSystemControlAction
          .getClipboard => const CockpitResolvedSystemControlCommand.error(
        code: 'systemActionBlocked',
        message:
            'Android clipboard actions require app instrumentation or an API-specific clipboard helper.',
      ),
      CockpitSystemControlAction.grantPermission => _grantPermissionCommand(
        request,
        (packageId, permission) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>['pm', 'grant', packageId, permission]),
        ),
      ),
      CockpitSystemControlAction.dismissSystemDialog =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['input', 'keyevent', 'KEYCODE_BACK']),
        ),
      CockpitSystemControlAction.captureScreenshot =>
        CockpitResolvedSystemControlCommand('adb', <String>[
          '-s',
          deviceId,
          'exec-out',
          'screencap',
          '-p',
        ]),
      CockpitSystemControlAction.startRecording ||
      CockpitSystemControlAction.stopRecording =>
        const CockpitResolvedSystemControlCommand.error(
          code: 'systemEvidenceAction',
          message: 'Recording actions are executed through recording adapters.',
        ),
      CockpitSystemControlAction.readUiTree =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>[
            'sh',
            '-c',
            'uiautomator dump /sdcard/window.xml >/dev/null && cat /sdcard/window.xml && rm /sdcard/window.xml',
          ]),
        ),
      CockpitSystemControlAction.readSystemState =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['dumpsys', 'window']),
        ),
      CockpitSystemControlAction.runShell => cockpitShellCommand(
        request,
        (command) => CockpitResolvedSystemControlCommand('adb', <String>[
          '-s',
          deviceId,
          'shell',
          ...command,
        ]),
      ),
    };
  }

  CockpitResolvedSystemControlCommand _grantPermissionCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(
      String packageId,
      String permission,
    )
    factory,
  ) {
    final packageId = _readPackageId(request);
    final permission = request.parameters['permission'] as String?;
    if (packageId == null ||
        packageId.trim().isEmpty ||
        permission == null ||
        permission.trim().isEmpty) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message:
            'grantPermission requires --app-id or packageId plus permission.',
      );
    }
    return factory(packageId.trim(), permission.trim());
  }

  CockpitResolvedSystemControlCommand _packageCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(String packageId) factory,
  ) {
    final packageId = _readPackageId(request);
    if (packageId == null || packageId.trim().isEmpty) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: '${request.action.name} requires --app-id or packageId.',
      );
    }
    return factory(packageId.trim());
  }

  String? _readPackageId(CockpitSystemControlActionRequest request) {
    return request.appId ??
        (request.parameters['packageId'] as String?) ??
        (request.parameters['appId'] as String?);
  }

  String _normalizeAndroidKey(String key) {
    final trimmed = key.trim();
    final lower = trimmed.toLowerCase();
    return switch (lower) {
      'enter' || 'return' => 'KEYCODE_ENTER',
      'escape' || 'esc' => 'KEYCODE_ESCAPE',
      'tab' => 'KEYCODE_TAB',
      'backspace' || 'delete' => 'KEYCODE_DEL',
      'space' => 'KEYCODE_SPACE',
      'back' => 'KEYCODE_BACK',
      'home' => 'KEYCODE_HOME',
      'menu' => 'KEYCODE_MENU',
      'volumeup' || 'volume_up' || 'volume-up' => 'KEYCODE_VOLUME_UP',
      'volumedown' || 'volume_down' || 'volume-down' => 'KEYCODE_VOLUME_DOWN',
      _ => trimmed,
    };
  }

  CockpitResolvedSystemControlCommand _androidSetAppearanceCommand(
    String appearance,
    CockpitResolvedSystemControlCommand Function(String mode) factory,
  ) {
    final mode = switch (appearance.trim().toLowerCase()) {
      'dark' || 'night' => 'yes',
      'light' || 'day' => 'no',
      'auto' || 'system' => 'auto',
      _ => null,
    };
    if (mode == null) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: 'setAppearance requires appearance light, dark, or auto.',
      );
    }
    return factory(mode);
  }

  CockpitResolvedSystemControlCommand _androidSetContentSizeCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(String fontScale) factory,
  ) {
    final raw =
        request.parameters['fontScale'] ?? request.parameters['contentSize'];
    if (raw == null || '$raw'.trim().isEmpty) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: 'setContentSize requires contentSize or fontScale parameter.',
      );
    }
    final value = '$raw'.trim();
    final numeric = double.tryParse(value);
    final fontScale = numeric ?? _androidFontScaleForContentSize(value);
    if (fontScale == null || fontScale < 0.5 || fontScale > 3.5) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message:
            'setContentSize requires a known content size token or font scale between 0.5 and 3.5.',
      );
    }
    return factory(_formatDecimal(fontScale));
  }

  double? _androidFontScaleForContentSize(String value) {
    return switch (value.trim().toLowerCase()) {
      'extra-small' => 0.85,
      'small' => 0.9,
      'medium' || 'normal' || 'large' => 1.0,
      'extra-large' => 1.15,
      'extra-extra-large' => 1.3,
      'extra-extra-extra-large' => 1.45,
      'accessibility-medium' => 1.6,
      'accessibility-large' => 1.8,
      'accessibility-extra-large' => 2.0,
      'accessibility-extra-extra-large' => 2.4,
      'accessibility-extra-extra-extra-large' => 2.8,
      _ => null,
    };
  }

  String _formatCoordinate(double value) => _formatDecimal(value);

  String _formatDecimal(double value) {
    final text = value.toStringAsFixed(6);
    return text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _escapeAdbText(String text) {
    return text
        .replaceAll('%', r'\%')
        .replaceAll(' ', '%s')
        .replaceAll('"', r'\"')
        .replaceAll("'", r"\'");
  }
}
