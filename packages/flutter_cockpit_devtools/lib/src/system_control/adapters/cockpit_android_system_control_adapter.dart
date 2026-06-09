import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cockpit_system_control_action.dart';
import '../cockpit_system_control_adapter.dart';
import '../cockpit_system_control_parameters.dart';
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
          parameters: CockpitSystemControlParameterSets.coordinate,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.longPress,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.swipe.hold',
          requires: <String>['adb', 'device id'],
          limitations: <String>['coordinate input has no semantic locator'],
          parameters: CockpitSystemControlParameterSets.longPress,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.drag,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.swipe',
          requires: <String>['adb', 'device id'],
          parameters: CockpitSystemControlParameterSets.drag,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.typeText,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.text',
          requires: <String>['adb', 'device id'],
          limitations: <String>['text must be escaped for adb input'],
          parameters: CockpitSystemControlParameterSets.text,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressKey,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.keyevent',
          requires: <String>['adb', 'device id', 'key name'],
          parameters: CockpitSystemControlParameterSets.key,
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
          action: CockpitSystemControlAction.pressVolumeUp,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.keyevent.KEYCODE_VOLUME_UP',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressVolumeDown,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.keyevent.KEYCODE_VOLUME_DOWN',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressVolumeMute,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.keyevent.KEYCODE_VOLUME_MUTE',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.activateWindow,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.monkey.launcher',
          requires: <String>['adb', 'device id', 'package id'],
          parameters: CockpitSystemControlParameterSets.androidApp,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.terminateApp,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.am.force-stop',
          requires: <String>['adb', 'device id', 'package id'],
          parameters: CockpitSystemControlParameterSets.androidApp,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.dismissSystemDialog,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.uiautomator.permission-button',
          requires: <String>['adb', 'device id'],
          limitations: <String>[
            'Matches common Android permission and system dialog button ids/text; custom OEM dialogs may still require coordinate or semantic fallback.',
          ],
          parameters: CockpitSystemControlParameterSets.systemDialogDecision,
          fallbackActions: <CockpitSystemControlAction>[
            CockpitSystemControlAction.pressBack,
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.dismissKeyboard,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.input.keyevent.KEYCODE_BACK',
          requires: <String>['adb', 'device id'],
          limitations: <String>[
            'Back dismisses the current IME when it is visible; otherwise it may navigate back.',
          ],
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
          parameters: CockpitSystemControlParameterSets.androidGrantPermission,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.openUrl,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.am.start.VIEW',
          requires: <String>['adb', 'device id'],
          parameters: CockpitSystemControlParameterSets.url,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.openSystemSettings,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.am.start.android.settings.SETTINGS',
          requires: <String>['adb', 'device id'],
          parameters: CockpitSystemControlParameterSets.systemSettings,
          limitations: <String>[
            'Use settingsAction for a custom android.settings.* action; default opens the main Settings app.',
          ],
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
          parameters: CockpitSystemControlParameterSets.androidAppearance,
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
          parameters: CockpitSystemControlParameterSets.androidContentSize,
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
          parameters: CockpitSystemControlParameterSets.location,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setOrientation,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.settings.user_rotation',
          requires: <String>['adb', 'device id', 'orientation'],
          limitations: <String>[
            'Changes the device-wide rotation setting; use auto to restore sensor rotation.',
          ],
          parameters: CockpitSystemControlParameterSets.androidOrientation,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setNetworkSpeed,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: emulatorAvailability,
          strategy: 'adb.emu.network.speed',
          requires: <String>['adb', 'Android emulator id', 'network speed'],
          limitations: <String>[
            'Android emulator console network speed is emulator-only.',
          ],
          parameters: CockpitSystemControlParameterSets.androidNetworkSpeed,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setNetworkDelay,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: emulatorAvailability,
          strategy: 'adb.emu.network.delay',
          requires: <String>['adb', 'Android emulator id', 'network delay'],
          limitations: <String>[
            'Android emulator console network delay is emulator-only.',
          ],
          parameters: CockpitSystemControlParameterSets.androidNetworkDelay,
        ),
        const CockpitSystemControlCapability(
          action: CockpitSystemControlAction.setStatusBar,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.unsupported,
          strategy: 'android-no-stable-status-bar-override',
          limitations: <String>[
            'Android does not expose a stable adb status bar override equivalent to iOS simulator status_bar.',
          ],
        ),
        const CockpitSystemControlCapability(
          action: CockpitSystemControlAction.clearStatusBar,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: CockpitSystemControlAvailability.unsupported,
          strategy: 'android-no-stable-status-bar-override',
          limitations: <String>[
            'Android does not expose a stable adb status bar override equivalent to iOS simulator status_bar.',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.expandNotifications,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.cmd.statusbar.expand-notifications',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.expandQuickSettings,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.cmd.statusbar.expand-settings',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.collapseSystemUi,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.cmd.statusbar.collapse',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.postNotification,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.cmd.notification.post',
          requires: <String>['adb', 'device id'],
          limitations: <String>[
            'Posts from the Android shell package; use app notification flows to validate production notification handling.',
          ],
          parameters: CockpitSystemControlParameterSets.androidNotification,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.clearNotifications,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.cmd.statusbar.collapse',
          requires: <String>['adb', 'device id'],
          limitations: <String>[
            'Android shell has no stable public clear-all-notifications command; this collapses system UI after notification assertions.',
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
          parameters: CockpitSystemControlParameterSets.screenshot,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.startRecording,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.screenrecord',
          requires: <String>['adb', 'device id'],
          limitations: <String>['Android screenrecord has duration limits'],
          parameters: CockpitSystemControlParameterSets.startRecording,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.stopRecording,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.screenrecord.stop-and-pull',
          requires: <String>['adb', 'device id', 'active recording session'],
          parameters: CockpitSystemControlParameterSets.stopRecording,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readUiTree,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: availability,
          strategy: 'adb.shell.uiautomator.dump',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readProcessList,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.ps',
          requires: <String>['adb', 'device id'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readWindows,
          plane: CockpitPlaneKind.deviceSystemPlane,
          availability: availability,
          strategy: 'adb.shell.dumpsys.window.windows',
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
          parameters: CockpitSystemControlParameterSets.shellCommand,
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
      CockpitSystemControlAction.longPress => cockpitLongPressCommand(
        request,
        (x, y, durationMs) => CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(<String>[
            'input',
            'swipe',
            '$x',
            '$y',
            '$x',
            '$y',
            '$durationMs',
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
      CockpitSystemControlAction.pressVolumeUp =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['input', 'keyevent', 'KEYCODE_VOLUME_UP']),
        ),
      CockpitSystemControlAction.pressVolumeDown =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['input', 'keyevent', 'KEYCODE_VOLUME_DOWN']),
        ),
      CockpitSystemControlAction.pressVolumeMute =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['input', 'keyevent', 'KEYCODE_VOLUME_MUTE']),
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
      CockpitSystemControlAction.openSystemSettings =>
        _androidOpenSystemSettingsCommand(
          request,
          (settingsAction) => CockpitResolvedSystemControlCommand(
            'adb',
            adbShell(<String>['am', 'start', '-a', settingsAction]),
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
      CockpitSystemControlAction.setOrientation =>
        _androidSetOrientationCommand(
          request,
          (script) => CockpitResolvedSystemControlCommand(
            'adb',
            adbShell(<String>['sh', '-c', script]),
          ),
        ),
      CockpitSystemControlAction.setNetworkSpeed =>
        _androidEmulatorNetworkCommand(
          request,
          deviceId: deviceId,
          parameterName: 'networkSpeed',
          commandName: 'speed',
          allowedValues: const <String>[
            'gsm',
            'hscsd',
            'gprs',
            'edge',
            'umts',
            'hsdpa',
            'lte',
            'evdo',
            'full',
          ],
        ),
      CockpitSystemControlAction.setNetworkDelay =>
        _androidEmulatorNetworkCommand(
          request,
          deviceId: deviceId,
          parameterName: 'networkDelay',
          commandName: 'delay',
          allowedValues: const <String>['gprs', 'edge', 'umts', 'none'],
        ),
      CockpitSystemControlAction.setStatusBar ||
      CockpitSystemControlAction.clearStatusBar => _unsupportedCommand(request),
      CockpitSystemControlAction.expandNotifications =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['cmd', 'statusbar', 'expand-notifications']),
        ),
      CockpitSystemControlAction.expandQuickSettings =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['cmd', 'statusbar', 'expand-settings']),
        ),
      CockpitSystemControlAction.collapseSystemUi ||
      CockpitSystemControlAction.clearNotifications =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['cmd', 'statusbar', 'collapse']),
        ),
      CockpitSystemControlAction.postNotification =>
        _androidPostNotificationCommand(
          request,
          (args) => CockpitResolvedSystemControlCommand(
            'adb',
            adbShell(<String>['cmd', 'notification', 'post', ...args]),
          ),
        ),
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
        _androidDismissSystemDialogCommand(
          request,
          (script) => CockpitResolvedSystemControlCommand(
            'adb',
            adbShell(<String>['sh', '-c', script]),
          ),
        ),
      CockpitSystemControlAction.dismissKeyboard =>
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
      CockpitSystemControlAction.readProcessList =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['ps', '-A']),
        ),
      CockpitSystemControlAction.readWindows =>
        CockpitResolvedSystemControlCommand(
          'adb',
          adbShell(const <String>['dumpsys', 'window', 'windows']),
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

  CockpitResolvedSystemControlCommand _unsupportedCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'unsupportedSystemAction',
      message: '${request.action.name} is not executable on Android.',
    );
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
    final permission = cockpitReadSystemControlStringParameter(
      request.parameters,
      'permission',
    );
    if (packageId.isInvalid || permission.isInvalid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message:
            'grantPermission requires string packageId/appId and permission parameters.',
      );
    }
    if (!packageId.isValid || !permission.isValid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message:
            'grantPermission requires --app-id or packageId plus permission.',
      );
    }
    return factory(packageId.value!, permission.value!);
  }

  CockpitResolvedSystemControlCommand _androidOpenSystemSettingsCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(String settingsAction) factory,
  ) {
    final value = cockpitReadSystemControlStringParameter(
      request.parameters,
      'settingsAction',
    );
    if (value.isInvalid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: 'openSystemSettings requires a string settingsAction.',
      );
    }
    return factory(value.value ?? 'android.settings.SETTINGS');
  }

  CockpitResolvedSystemControlCommand _androidPostNotificationCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(List<String> args) factory,
  ) {
    final payloadJson = cockpitReadSystemControlStringParameter(
      request.parameters,
      'payloadJson',
    );
    if (payloadJson.isPresent) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'unsupportedSystemActionParameter',
        message:
            'Android postNotification does not accept payloadJson; use title and body.',
      );
    }
    final title = cockpitReadSystemControlStringParameter(
      request.parameters,
      'title',
    );
    final body = cockpitReadSystemControlStringParameter(
      request.parameters,
      'body',
    );
    final tag = cockpitReadSystemControlStringParameter(
      request.parameters,
      'tag',
    );
    if (title.isInvalid || body.isInvalid || tag.isInvalid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: 'postNotification accepts string title, body, and tag.',
      );
    }
    final notificationBody = body.value ?? title.value;
    if (notificationBody == null || notificationBody.trim().isEmpty) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: 'postNotification requires title or body.',
      );
    }
    return factory(<String>[
      if (title.value != null) ...<String>['--title', title.value!],
      tag.value ?? 'flutter-cockpit',
      notificationBody,
    ]);
  }

  CockpitResolvedSystemControlCommand _androidDismissSystemDialogCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(String script) factory,
  ) {
    final decision = cockpitReadSystemControlStringParameter(
      request.parameters,
      'decision',
      allowedValues: const <String>['accept', 'dismiss'],
    );
    if (decision.isInvalid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message:
            'dismissSystemDialog decision must be accept or dismiss when provided.',
      );
    }
    final mode = decision.value ?? 'accept';
    return factory(_androidDismissSystemDialogScript(mode));
  }

  String _androidDismissSystemDialogScript(String decision) {
    final buttonSpecs = decision == 'dismiss'
        ? const <String>[
            'resource-id="com.android.permissioncontroller:id/permission_deny_button"',
            'resource-id="com.android.packageinstaller:id/permission_deny_button"',
            'text="Deny"',
            'text="DENY"',
            'text="Don\\u2019t allow"',
            'text="Cancel"',
            'text="CANCEL"',
          ]
        : const <String>[
            'resource-id="com.android.permissioncontroller:id/permission_allow_button"',
            'resource-id="com.android.permissioncontroller:id/permission_allow_foreground_only_button"',
            'resource-id="com.android.permissioncontroller:id/permission_allow_one_time_button"',
            'resource-id="com.android.packageinstaller:id/permission_allow_button"',
            'text="Allow"',
            'text="ALLOW"',
            'text="While using the app"',
            'text="Only this time"',
            'text="OK"',
          ];
    final patterns = buttonSpecs.map((spec) => "  -e '$spec'").join(' ');
    final notFoundFallback = decision == 'dismiss'
        ? 'input keyevent KEYCODE_BACK'
        : 'echo "flutter_cockpit: no matching Android system dialog accept button" >&2; exit 2';
    return '''
set -e
dump="/sdcard/flutter_cockpit_window.xml"
uiautomator dump "\$dump" >/dev/null
match=\$(grep -E $patterns "\$dump" | head -n 1 || true)
rm -f "\$dump"
if [ -z "\$match" ]; then
  $notFoundFallback
  exit \$?
fi
bounds=\$(printf "%s" "\$match" | sed -n 's/.*bounds="\\[\\([0-9][0-9]*\\),\\([0-9][0-9]*\\)\\]\\[\\([0-9][0-9]*\\),\\([0-9][0-9]*\\)\\]".*/\\1 \\2 \\3 \\4/p')
if [ -z "\$bounds" ]; then
  echo "flutter_cockpit: Android system dialog button had no bounds" >&2
  exit 2
fi
set -- \$bounds
x=\$(( (\$1 + \$3) / 2 ))
y=\$(( (\$2 + \$4) / 2 ))
input tap "\$x" "\$y"
''';
  }

  CockpitResolvedSystemControlCommand _packageCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(String packageId) factory,
  ) {
    final packageId = _readPackageId(request);
    if (packageId.isInvalid) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: '${request.action.name} requires a string packageId or appId.',
      );
    }
    if (!packageId.isValid) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: '${request.action.name} requires --app-id or packageId.',
      );
    }
    return factory(packageId.value!);
  }

  CockpitSystemControlStringParameter _readPackageId(
    CockpitSystemControlActionRequest request,
  ) {
    final appId = request.appId?.trim();
    if (appId != null && appId.isNotEmpty) {
      return CockpitSystemControlStringParameter.valid(appId);
    }
    return cockpitReadFirstSystemControlStringParameter(
      request.parameters,
      const <String>['packageId'],
    );
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
      'dark' => 'yes',
      'light' => 'no',
      'auto' => 'auto',
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
    final fontScaleParameter = cockpitReadSystemControlDoubleParameter(
      request.parameters,
      'fontScale',
      minimum: 0.5,
      maximum: 3.5,
    );
    final contentSizeParameter = cockpitReadSystemControlStringParameter(
      request.parameters,
      'contentSize',
    );
    if (fontScaleParameter.isInvalid || contentSizeParameter.isInvalid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message:
            'setContentSize requires a known content size token or font scale between 0.5 and 3.5.',
      );
    }
    if (!fontScaleParameter.isValid && !contentSizeParameter.isValid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: 'setContentSize requires contentSize or fontScale parameter.',
      );
    }
    final fontScale =
        fontScaleParameter.value ??
        _androidFontScaleForContentSize(contentSizeParameter.value!);
    if (fontScale == null) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message:
            'setContentSize requires a known content size token or font scale between 0.5 and 3.5.',
      );
    }
    return factory(_formatDecimal(fontScale));
  }

  CockpitResolvedSystemControlCommand _androidSetOrientationCommand(
    CockpitSystemControlActionRequest request,
    CockpitResolvedSystemControlCommand Function(String script) factory,
  ) {
    final raw = cockpitReadSystemControlStringParameter(
      request.parameters,
      'orientation',
    );
    if (raw.isInvalid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message: 'setOrientation requires a string orientation parameter.',
      );
    }
    if (!raw.isValid) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: 'setOrientation requires an orientation parameter.',
      );
    }
    final orientation = raw.value!;
    if (orientation == 'auto') {
      return factory('settings put system accelerometer_rotation 1');
    }
    final rotation = switch (orientation) {
      'portrait' => 0,
      'landscape' => 1,
      'reversePortrait' => 2,
      'reverseLandscape' => 3,
      _ => null,
    };
    if (rotation == null) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message:
            'setOrientation requires portrait, landscape, reversePortrait, reverseLandscape, or auto.',
      );
    }
    return factory(
      'settings put system accelerometer_rotation 0 && settings put system user_rotation $rotation',
    );
  }

  CockpitResolvedSystemControlCommand _androidEmulatorNetworkCommand(
    CockpitSystemControlActionRequest request, {
    required String deviceId,
    required String parameterName,
    required String commandName,
    required List<String> allowedValues,
  }) {
    if (!deviceId.startsWith('emulator-')) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'systemActionBlocked',
        message: 'Android $commandName is available only for emulator-* ids.',
      );
    }
    final value = cockpitReadSystemControlStringParameter(
      request.parameters,
      parameterName,
      allowedValues: allowedValues,
    );
    if (value.isInvalid) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'invalidSystemActionParameter',
        message:
            '${request.action.name} requires one of ${allowedValues.join(", ")}.',
      );
    }
    if (!value.isValid) {
      return CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionParameter',
        message: '${request.action.name} requires a $parameterName parameter.',
      );
    }
    return CockpitResolvedSystemControlCommand('adb', <String>[
      '-s',
      deviceId,
      'emu',
      'network',
      commandName,
      value.value!,
    ]);
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
