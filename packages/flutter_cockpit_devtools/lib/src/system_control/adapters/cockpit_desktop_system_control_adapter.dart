import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cockpit_system_control_action.dart';
import '../cockpit_system_control_adapter.dart';
import '../cockpit_system_control_profile.dart';

final class CockpitDesktopSystemControlAdapter
    implements CockpitSystemControlAdapter {
  const CockpitDesktopSystemControlAdapter({
    required this.platform,
    required this.adapter,
    required this.inputStrategy,
    required this.screenshotStrategy,
    required this.recordingStrategy,
    required this.requires,
    this.limitations = const <String>[],
  });

  @override
  final String platform;
  final String adapter;
  final String inputStrategy;
  final String screenshotStrategy;
  final String recordingStrategy;
  final List<String> requires;
  final List<String> limitations;

  @override
  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  ) {
    final hasInputTarget = target.hasWindowTarget;
    final hasEvidenceTarget = platform == 'macos'
        ? target.appId != null && target.appId!.trim().isNotEmpty
        : target.hasWindowTarget;
    return CockpitSystemControlProfile(
      platform: platform,
      deviceId: target.deviceId,
      appId: target.appId,
      processId: target.processId,
      adapter: adapter,
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.nativeUiPlane,
        CockpitPlaneKind.deviceSystemPlane,
        CockpitPlaneKind.hostPlane,
      ],
      recommendedNextStep: 'preferFlutterSemanticPlane',
      capabilities: <CockpitSystemControlCapability>[
        _coordinateInputCapability(CockpitSystemControlAction.tap),
        _coordinateInputCapability(CockpitSystemControlAction.longPress),
        _coordinateInputCapability(CockpitSystemControlAction.drag),
        _targetedInputCapability(
          CockpitSystemControlAction.typeText,
          hasInputTarget: hasInputTarget,
        ),
        _targetedInputCapability(
          CockpitSystemControlAction.pressBack,
          hasInputTarget: hasInputTarget,
        ),
        _unsupported(
          CockpitSystemControlAction.pressHome,
          'mobile-home-key',
          'Desktop platforms do not have a stable app-scoped Home action.',
        ),
        _targetedInputCapability(
          CockpitSystemControlAction.activateWindow,
          hasInputTarget: hasInputTarget,
        ),
        _targetedInputCapability(
          CockpitSystemControlAction.dismissSystemDialog,
          hasInputTarget: hasInputTarget,
        ),
        _unsupported(
          CockpitSystemControlAction.grantPermission,
          'platform-permission-manager',
          'Desktop permission prompts require app-specific or OS-specific workflows.',
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.openUrl,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.available,
          strategy: _openUrlStrategy,
          requires: _openUrlRequires,
          limitations: limitations,
        ),
        _evidenceCapability(
          CockpitSystemControlAction.captureScreenshot,
          screenshotStrategy,
          hasWindowTarget: hasEvidenceTarget,
        ),
        _evidenceCapability(
          CockpitSystemControlAction.startRecording,
          recordingStrategy,
          hasWindowTarget: hasEvidenceTarget,
        ),
        _evidenceCapability(
          CockpitSystemControlAction.stopRecording,
          recordingStrategy,
          hasWindowTarget: hasEvidenceTarget,
          extraRequires: const <String>['active recording session'],
        ),
        _blocked(CockpitSystemControlAction.readUiTree, _uiTreeStrategy),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readSystemState,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.available,
          strategy: _systemStateStrategy,
          requires: _systemStateRequires,
          limitations: limitations,
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.runShell,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.available,
          strategy: 'host.shell',
          requires: _shellRequires,
          limitations: limitations,
        ),
      ],
    );
  }

  @override
  CockpitResolvedSystemControlCommand resolveCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return switch (platform) {
      'macos' => _resolveMacosCommand(request),
      'windows' => _resolveWindowsCommand(request),
      'linux' => _resolveLinuxCommand(request),
      _ => CockpitResolvedSystemControlCommand.error(
        code: 'unsupportedPlatform',
        message: 'No desktop system control adapter for $platform.',
      ),
    };
  }

  String get _openUrlStrategy {
    return switch (platform) {
      'macos' => 'open.url',
      'windows' => 'powershell.start-process.url',
      'linux' => 'xdg-open.url',
      _ => 'host.open-url',
    };
  }

  List<String> get _openUrlRequires {
    return switch (platform) {
      'macos' => const <String>['open'],
      'windows' => const <String>['PowerShell'],
      'linux' => const <String>['xdg-open'],
      _ => const <String>['host URL opener'],
    };
  }

  String get _uiTreeStrategy {
    return switch (platform) {
      'macos' => 'accessibility-tree-dumper',
      'windows' => 'UIAutomation tree walker',
      'linux' => 'AT-SPI tree walker',
      _ => 'native accessibility tree',
    };
  }

  String get _systemStateStrategy {
    return switch (platform) {
      'macos' => 'sw_vers+uname',
      'windows' => 'powershell.cim.operating-system',
      'linux' => 'uname+desktop-session-env',
      _ => 'host.system-state',
    };
  }

  List<String> get _systemStateRequires {
    return switch (platform) {
      'macos' => const <String>['sw_vers', 'uname'],
      'windows' => const <String>['PowerShell'],
      'linux' => const <String>['uname', 'host shell'],
      _ => const <String>['host shell'],
    };
  }

  List<String> get _shellRequires {
    return switch (platform) {
      'macos' || 'linux' => const <String>['host shell'],
      'windows' => const <String>['interactive desktop session'],
      _ => const <String>['host shell'],
    };
  }

  List<String> get _coordinateInputRequires {
    return switch (platform) {
      'macos' => const <String>[
        'Accessibility permission',
        'interactive desktop session',
      ],
      'windows' => const <String>['interactive desktop session'],
      'linux' => const <String>['xdotool', 'X11 DISPLAY'],
      _ => requires,
    };
  }

  List<String> get _uiTreeRequires {
    return switch (platform) {
      'macos' => const <String>[
        'Accessibility permission',
        'Accessibility tree dump helper',
      ],
      'windows' => const <String>['UI Automation tree dump helper'],
      'linux' => const <String>['AT-SPI tree dump helper'],
      _ => const <String>['native accessibility tree helper'],
    };
  }

  List<String> get _targetedInputRequires {
    return switch (platform) {
      'macos' => const <String>[
        'Accessibility permission',
        'Automation permission for System Events',
        'interactive desktop session',
      ],
      'windows' => const <String>['interactive desktop session'],
      'linux' => const <String>['xdotool', 'X11 DISPLAY'],
      _ => requires,
    };
  }

  List<String> get _screenshotRequires {
    return switch (platform) {
      'macos' => const <String>[
        'screencapture',
        'osascript',
        'Screen Recording permission',
      ],
      'windows' => const <String>['PowerShell', 'interactive desktop session'],
      'linux' => const <String>[
        'desktop session',
        'wmctrl recommended',
        'one screenshot tool: gnome-screenshot, grim, scrot, or import',
      ],
      _ => requires,
    };
  }

  List<String> get _recordingRequires {
    return switch (platform) {
      'macos' => const <String>[
        'ffmpeg',
        'osascript',
        'Screen Recording permission',
      ],
      'windows' => const <String>[
        'ffmpeg',
        'PowerShell',
        'interactive desktop session',
      ],
      'linux' => const <String>['ffmpeg', 'X11 DISPLAY'],
      _ => requires,
    };
  }

  CockpitResolvedSystemControlCommand _resolveMacosCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return switch (request.action) {
      CockpitSystemControlAction.tap => cockpitCoordinateCommand(
        request,
        (x, y) => _macosJxa(<String>[
          _macosMouseScript,
          'tap',
          '$x',
          '$y',
          '$x',
          '$y',
          '0',
        ]),
      ),
      CockpitSystemControlAction.longPress => cockpitCoordinateCommand(
        request,
        (x, y) => _macosJxa(<String>[
          _macosMouseScript,
          'longPress',
          '$x',
          '$y',
          '$x',
          '$y',
          '${cockpitReadSystemControlInt(request.parameters, 'durationMs') ?? 800}',
        ]),
      ),
      CockpitSystemControlAction.drag => cockpitDragCommand(request, (
        startX,
        startY,
        endX,
        endY,
        durationMs,
      ) {
        return _macosJxa(<String>[
          _macosMouseScript,
          'drag',
          '$startX',
          '$startY',
          '$endX',
          '$endY',
          '$durationMs',
        ]);
      }),
      CockpitSystemControlAction.typeText => cockpitTextCommand(
        request,
        'text',
        (text) => _macosAppleScriptWithTarget(
          request,
          _macosTypeTextScript,
          <String>[text],
        ),
      ),
      CockpitSystemControlAction.pressBack => _macosAppleScriptWithTarget(
        request,
        _macosPressBackScript,
      ),
      CockpitSystemControlAction.activateWindow => _macosAppleScriptWithTarget(
        request,
        _macosActivateTargetScript,
      ),
      CockpitSystemControlAction.dismissSystemDialog =>
        _macosAppleScriptWithTarget(request, _macosPressBackScript),
      CockpitSystemControlAction.openUrl => cockpitTextCommand(
        request,
        'url',
        (url) => CockpitResolvedSystemControlCommand('open', <String>[url]),
      ),
      CockpitSystemControlAction.readSystemState =>
        CockpitResolvedSystemControlCommand('sh', const <String>[
          '-c',
          'sw_vers && uname -a',
        ]),
      CockpitSystemControlAction.runShell => cockpitShellCommand(
        request,
        (command) => CockpitResolvedSystemControlCommand(
          command.first,
          command.skip(1).toList(growable: false),
        ),
      ),
      CockpitSystemControlAction.captureScreenshot ||
      CockpitSystemControlAction.startRecording ||
      CockpitSystemControlAction
          .stopRecording => const CockpitResolvedSystemControlCommand.error(
        code: 'systemEvidenceAction',
        message:
            'Evidence actions are executed through capture and recording adapters.',
      ),
      _ => _unsupportedCommand(request),
    };
  }

  CockpitResolvedSystemControlCommand _resolveWindowsCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return switch (request.action) {
      CockpitSystemControlAction.tap => cockpitCoordinateCommand(
        request,
        (x, y) => _windowsInput(<String>['tap', '', '', '$x', '$y']),
      ),
      CockpitSystemControlAction.longPress => cockpitCoordinateCommand(
        request,
        (x, y) => _windowsInput(<String>[
          'longPress',
          '',
          '',
          '$x',
          '$y',
          '${cockpitReadSystemControlInt(request.parameters, 'durationMs') ?? 800}',
        ]),
      ),
      CockpitSystemControlAction.drag => cockpitDragCommand(request, (
        startX,
        startY,
        endX,
        endY,
        durationMs,
      ) {
        return _windowsInput(<String>[
          'drag',
          '',
          '',
          '$startX',
          '$startY',
          '$endX',
          '$endY',
          '$durationMs',
        ]);
      }),
      CockpitSystemControlAction.typeText => cockpitTextCommand(
        request,
        'text',
        (text) => _windowsInput(<String>[
          'typeText',
          request.appId ?? '',
          request.processId?.toString() ?? '',
          text,
        ]),
      ),
      CockpitSystemControlAction.pressBack => _windowsInput(<String>[
        'pressBack',
        request.appId ?? '',
        request.processId?.toString() ?? '',
      ]),
      CockpitSystemControlAction.activateWindow => _windowsInput(<String>[
        'activateWindow',
        request.appId ?? '',
        request.processId?.toString() ?? '',
      ]),
      CockpitSystemControlAction.dismissSystemDialog => _windowsInput(<String>[
        'pressBack',
        request.appId ?? '',
        request.processId?.toString() ?? '',
      ]),
      CockpitSystemControlAction.openUrl => cockpitTextCommand(
        request,
        'url',
        (url) => CockpitResolvedSystemControlCommand('powershell', <String>[
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'Start-Process -FilePath $args[0]',
          url,
        ]),
      ),
      CockpitSystemControlAction.readSystemState =>
        CockpitResolvedSystemControlCommand('powershell', const <String>[
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture | ConvertTo-Json -Compress',
        ]),
      CockpitSystemControlAction.runShell => cockpitShellCommand(
        request,
        (command) => CockpitResolvedSystemControlCommand(
          command.first,
          command.skip(1).toList(growable: false),
        ),
      ),
      CockpitSystemControlAction.captureScreenshot ||
      CockpitSystemControlAction.startRecording ||
      CockpitSystemControlAction
          .stopRecording => const CockpitResolvedSystemControlCommand.error(
        code: 'systemEvidenceAction',
        message:
            'Evidence actions are executed through capture and recording adapters.',
      ),
      _ => _unsupportedCommand(request),
    };
  }

  CockpitResolvedSystemControlCommand _resolveLinuxCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return switch (request.action) {
      CockpitSystemControlAction.tap => cockpitCoordinateCommand(
        request,
        (x, y) => CockpitResolvedSystemControlCommand('xdotool', <String>[
          'mousemove',
          '$x',
          '$y',
          'click',
          '1',
        ]),
      ),
      CockpitSystemControlAction.longPress => cockpitCoordinateCommand(
        request,
        (x, y) => CockpitResolvedSystemControlCommand('xdotool', <String>[
          'mousemove',
          '$x',
          '$y',
          'mousedown',
          '1',
          'sleep',
          '${(cockpitReadSystemControlInt(request.parameters, 'durationMs') ?? 800) / 1000.0}',
          'mouseup',
          '1',
        ]),
      ),
      CockpitSystemControlAction.drag => cockpitDragCommand(request, (
        startX,
        startY,
        endX,
        endY,
        durationMs,
      ) {
        return CockpitResolvedSystemControlCommand('xdotool', <String>[
          'mousemove',
          '$startX',
          '$startY',
          'mousedown',
          '1',
          'sleep',
          '${durationMs / 1000.0}',
          'mousemove',
          '--sync',
          '$endX',
          '$endY',
          'mouseup',
          '1',
        ]);
      }),
      CockpitSystemControlAction.typeText => cockpitTextCommand(
        request,
        'text',
        (text) => _linuxTargetedXdotool(request, <String>[
          'type',
          '--clearmodifiers',
          '--delay',
          '0',
          text,
        ]),
      ),
      CockpitSystemControlAction.pressBack => _linuxTargetedXdotool(
        request,
        const <String>['key', 'Escape'],
      ),
      CockpitSystemControlAction.activateWindow => _linuxTargetedXdotool(
        request,
        const <String>[],
      ),
      CockpitSystemControlAction.dismissSystemDialog => _linuxTargetedXdotool(
        request,
        const <String>['key', 'Escape'],
      ),
      CockpitSystemControlAction.openUrl => cockpitTextCommand(
        request,
        'url',
        (url) => CockpitResolvedSystemControlCommand('xdg-open', <String>[url]),
      ),
      CockpitSystemControlAction.readSystemState =>
        CockpitResolvedSystemControlCommand('sh', const <String>[
          '-c',
          r'uname -a && printf "XDG_SESSION_TYPE=%s\nXDG_CURRENT_DESKTOP=%s\nWAYLAND_DISPLAY=%s\nDISPLAY=%s\n" "$XDG_SESSION_TYPE" "$XDG_CURRENT_DESKTOP" "$WAYLAND_DISPLAY" "$DISPLAY"',
        ]),
      CockpitSystemControlAction.runShell => cockpitShellCommand(
        request,
        (command) => CockpitResolvedSystemControlCommand(
          command.first,
          command.skip(1).toList(growable: false),
        ),
      ),
      CockpitSystemControlAction.captureScreenshot ||
      CockpitSystemControlAction.startRecording ||
      CockpitSystemControlAction
          .stopRecording => const CockpitResolvedSystemControlCommand.error(
        code: 'systemEvidenceAction',
        message:
            'Evidence actions are executed through capture and recording adapters.',
      ),
      _ => _unsupportedCommand(request),
    };
  }

  CockpitResolvedSystemControlCommand _macosJxa(List<String> scriptAndArgs) {
    return CockpitResolvedSystemControlCommand('osascript', <String>[
      '-l',
      'JavaScript',
      '-e',
      ...scriptAndArgs,
    ]);
  }

  CockpitResolvedSystemControlCommand _macosAppleScriptWithTarget(
    CockpitSystemControlActionRequest request,
    String script, [
    List<String> extraArgs = const <String>[],
  ]) {
    final target = _targetArgs(request);
    if (target == null) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionTarget',
        message: 'This macOS action requires --app-id or --process-id.',
      );
    }
    return CockpitResolvedSystemControlCommand('osascript', <String>[
      '-e',
      script,
      ...target,
      ...extraArgs,
    ]);
  }

  CockpitResolvedSystemControlCommand _windowsInput(List<String> args) {
    return CockpitResolvedSystemControlCommand('powershell', <String>[
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      _windowsInputScript,
      ...args,
    ]);
  }

  CockpitResolvedSystemControlCommand _linuxTargetedXdotool(
    CockpitSystemControlActionRequest request,
    List<String> xdotoolArgs,
  ) {
    final target = _targetArgs(request);
    if (target == null) {
      return const CockpitResolvedSystemControlCommand.error(
        code: 'missingSystemActionTarget',
        message: 'This Linux action requires --app-id or --process-id.',
      );
    }
    return CockpitResolvedSystemControlCommand('sh', <String>[
      '-c',
      _linuxTargetedXdotoolScript,
      'flutter_cockpit_linux_input',
      ...target,
      ...xdotoolArgs,
    ]);
  }

  List<String>? _targetArgs(CockpitSystemControlActionRequest request) {
    final appId = request.appId?.trim();
    final processId = request.processId;
    if (processId != null) {
      return <String>['processId', '$processId'];
    }
    if (appId != null && appId.isNotEmpty) {
      return <String>['appId', appId];
    }
    return null;
  }

  CockpitResolvedSystemControlCommand _unsupportedCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'unsupportedSystemAction',
      message: '${request.action.name} is not executable on $platform.',
    );
  }

  CockpitSystemControlCapability _coordinateInputCapability(
    CockpitSystemControlAction action,
  ) {
    return CockpitSystemControlCapability(
      action: action,
      plane: CockpitPlaneKind.deviceSystemPlane,
      availability: CockpitSystemControlAvailability.available,
      strategy: inputStrategy,
      requires: _coordinateInputRequires,
      limitations: <String>[
        ...limitations,
        'coordinate input has no semantic locator',
      ],
    );
  }

  CockpitSystemControlCapability _targetedInputCapability(
    CockpitSystemControlAction action, {
    required bool hasInputTarget,
  }) {
    return CockpitSystemControlCapability(
      action: action,
      plane: CockpitPlaneKind.nativeUiPlane,
      availability: hasInputTarget
          ? CockpitSystemControlAvailability.available
          : CockpitSystemControlAvailability.blocked,
      strategy: inputStrategy,
      requires: <String>[
        ..._targetedInputRequires,
        if (!hasInputTarget) 'app id or process id',
      ],
      limitations: limitations,
    );
  }

  CockpitSystemControlCapability _blocked(
    CockpitSystemControlAction action,
    String strategy, {
    List<String> extraRequires = const <String>[],
  }) {
    return CockpitSystemControlCapability(
      action: action,
      plane:
          action == CockpitSystemControlAction.captureScreenshot ||
              action == CockpitSystemControlAction.startRecording ||
              action == CockpitSystemControlAction.stopRecording
          ? CockpitPlaneKind.hostPlane
          : CockpitPlaneKind.nativeUiPlane,
      availability: CockpitSystemControlAvailability.blocked,
      strategy: strategy,
      requires: <String>[
        ...(action == CockpitSystemControlAction.readUiTree
            ? _uiTreeRequires
            : requires),
        ...extraRequires,
      ],
      limitations: limitations,
    );
  }

  CockpitSystemControlCapability _unsupported(
    CockpitSystemControlAction action,
    String strategy,
    String limitation,
  ) {
    return CockpitSystemControlCapability(
      action: action,
      plane: CockpitPlaneKind.hostPlane,
      availability: CockpitSystemControlAvailability.unsupported,
      strategy: strategy,
      limitations: <String>[...limitations, limitation],
    );
  }

  CockpitSystemControlCapability _evidenceCapability(
    CockpitSystemControlAction action,
    String strategy, {
    required bool hasWindowTarget,
    List<String> extraRequires = const <String>[],
  }) {
    return CockpitSystemControlCapability(
      action: action,
      plane: CockpitPlaneKind.hostPlane,
      availability: hasWindowTarget
          ? CockpitSystemControlAvailability.available
          : CockpitSystemControlAvailability.blocked,
      strategy: strategy,
      requires: <String>[
        ...(action == CockpitSystemControlAction.captureScreenshot
            ? _screenshotRequires
            : _recordingRequires),
        if (!hasWindowTarget) 'app id or process id',
        ...extraRequires,
      ],
      limitations: limitations,
    );
  }

  static const String _macosMouseScript = r'''
function run(argv) {
  const action = argv[0]
  const startX = Number(argv[1])
  const startY = Number(argv[2])
  const endX = Number(argv[3])
  const endY = Number(argv[4])
  const durationMs = Number(argv[5] || '0')
  ObjC.import('ApplicationServices')
  const eventTap = 0
  const leftButton = 0
  const mouseDown = 1
  const mouseUp = 2
  const mouseDragged = 6
  function point(x, y) { return $.CGPointMake(x, y) }
  function post(kind, x, y) {
    const event = $.CGEventCreateMouseEvent(null, kind, point(x, y), leftButton)
    $.CGEventPost(eventTap, event)
  }
  post(mouseDown, startX, startY)
  if (action === 'drag') {
    delay(Math.max(durationMs, 1) / 1000.0)
    post(mouseDragged, endX, endY)
  } else if (action === 'longPress') {
    delay(Math.max(durationMs, 1) / 1000.0)
  } else {
    delay(0.05)
  }
  post(mouseUp, endX, endY)
}
''';

  static const String _macosActivateTargetScript = r'''
on run argv
  set targetKind to item 1 of argv
  set targetValue to item 2 of argv
  if targetKind is "appId" then
    tell application id targetValue to activate
  else
    tell application "System Events"
      set frontmost of first application process whose unix id is (targetValue as integer) to true
    end tell
  end if
end run
''';

  static const String _macosTypeTextScript = r'''
on run argv
  set targetKind to item 1 of argv
  set targetValue to item 2 of argv
  set textValue to item 3 of argv
  if targetKind is "appId" then
    tell application id targetValue to activate
  else
    tell application "System Events"
      set frontmost of first application process whose unix id is (targetValue as integer) to true
    end tell
  end if
  tell application "System Events" to keystroke textValue
end run
''';

  static const String _macosPressBackScript = r'''
on run argv
  set targetKind to item 1 of argv
  set targetValue to item 2 of argv
  if targetKind is "appId" then
    tell application id targetValue to activate
  else
    tell application "System Events"
      set frontmost of first application process whose unix id is (targetValue as integer) to true
    end tell
  end if
  tell application "System Events" to key code 53
end run
''';

  static const String _windowsInputScript = r'''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class CockpitInputInterop {
  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);

  [DllImport("user32.dll")]
  public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

  [DllImport("user32.dll")]
  public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
}
"@
$action = $args[0]
$appId = $args[1]
$processIdArg = $args[2]
function Resolve-TargetProcess {
  if (-not [string]::IsNullOrWhiteSpace($processIdArg)) {
    return Get-Process -Id ([int]$processIdArg) -ErrorAction Stop |
      Where-Object { $_.MainWindowHandle -ne 0 } |
      Select-Object -First 1
  }
  if (-not [string]::IsNullOrWhiteSpace($appId)) {
    return Get-Process -Name $appId -ErrorAction Stop |
      Where-Object { $_.MainWindowHandle -ne 0 } |
      Sort-Object -Property Id -Descending |
      Select-Object -First 1
  }
  return $null
}
function Activate-Target {
  $process = Resolve-TargetProcess
  if ($null -eq $process) {
    throw "No target window was found for process '$appId' '$processIdArg'."
  }
  $handle = [IntPtr]$process.MainWindowHandle
  [void][CockpitInputInterop]::ShowWindowAsync($handle, 9)
  [void][CockpitInputInterop]::SetForegroundWindow($handle)
  Start-Sleep -Milliseconds 150
}
function Click-At($x, $y, $holdMs) {
  [System.Windows.Forms.Cursor]::Position = [System.Drawing.Point]::new($x, $y)
  [CockpitInputInterop]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds $holdMs
  [CockpitInputInterop]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}
function Escape-SendKeys([string]$value) {
  return $value.Replace('{', '{{}').Replace('}', '{}}').Replace('+', '{+}').Replace('^', '{^}').Replace('%', '{%}').Replace('~', '{~}').Replace('(', '{(}').Replace(')', '{)}').Replace('[', '{[}').Replace(']', '{]}')
}
switch ($action) {
  'activateWindow' { Activate-Target }
  'tap' { Click-At ([int]$args[3]) ([int]$args[4]) 50 }
  'longPress' { Click-At ([int]$args[3]) ([int]$args[4]) ([int]$args[5]) }
  'drag' {
    $startX = [int]$args[3]
    $startY = [int]$args[4]
    $endX = [int]$args[5]
    $endY = [int]$args[6]
    $durationMs = [int]$args[7]
    [System.Windows.Forms.Cursor]::Position = [System.Drawing.Point]::new($startX, $startY)
    [CockpitInputInterop]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds $durationMs
    [System.Windows.Forms.Cursor]::Position = [System.Drawing.Point]::new($endX, $endY)
    [CockpitInputInterop]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
  }
  'typeText' {
    Activate-Target
    [System.Windows.Forms.SendKeys]::SendWait((Escape-SendKeys $args[3]))
  }
  'pressBack' {
    Activate-Target
    [System.Windows.Forms.SendKeys]::SendWait('{ESC}')
  }
  default { throw "Unsupported cockpit input action: $action" }
}
''';

  static const String _linuxTargetedXdotoolScript = r'''
target_kind="$1"
target_value="$2"
shift 2
window_id=""
if [ "$target_kind" = "processId" ]; then
  window_id="$(xdotool search --onlyvisible --pid "$target_value" 2>/dev/null | head -n 1)"
elif [ "$target_kind" = "appId" ]; then
  window_id="$(xdotool search --onlyvisible --class "$target_value" 2>/dev/null | head -n 1)"
fi
if [ -z "$window_id" ]; then
  exit 65
fi
if [ "$#" -eq 0 ]; then
  exec xdotool windowactivate --sync "$window_id"
fi
exec xdotool windowactivate --sync "$window_id" "$@"
''';
}

final class CockpitWebSystemControlAdapter
    implements CockpitSystemControlAdapter {
  const CockpitWebSystemControlAdapter();

  @override
  String get platform => 'web';

  @override
  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  ) {
    return CockpitSystemControlProfile(
      platform: platform,
      deviceId: target.deviceId,
      appId: target.appId,
      processId: target.processId,
      adapter: 'browser.dom+host-recording',
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.nativeUiPlane,
        CockpitPlaneKind.hostPlane,
      ],
      recommendedNextStep: 'preferFlutterSemanticPlane',
      capabilities: const <CockpitSystemControlCapability>[
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.tap,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.dom.click',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.longPress,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.dom.pointer.longPress',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.drag,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.dom.pointer.drag',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.typeText,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.dom.input',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressBack,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.navigation.back',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.pressHome,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.unsupported,
          strategy: 'browser-no-home-key',
          limitations: <String>[
            'Browsers do not expose a stable app-scoped Home key.',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.activateWindow,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.window.focus',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.dismissSystemDialog,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.dialog.dismiss',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.grantPermission,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.context.permissions',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.openUrl,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.page.goto',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.captureScreenshot,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.screenshot',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.startRecording,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser-host-recording',
          requires: <String>['ffmpeg', 'host screen capture permission'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.stopRecording,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser-host-recording.stop',
          requires: <String>[
            'ffmpeg',
            'host screen capture permission',
            'active recording session',
          ],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readUiTree,
          plane: CockpitPlaneKind.nativeUiPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.accessibility.snapshot',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.readSystemState,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.blocked,
          strategy: 'browser.context.state',
          requires: <String>['browser driver or bridge'],
        ),
        CockpitSystemControlCapability(
          action: CockpitSystemControlAction.runShell,
          plane: CockpitPlaneKind.hostPlane,
          availability: CockpitSystemControlAvailability.unsupported,
          strategy: 'browser-no-shell',
          limitations: <String>[
            'Browser pages do not expose a system shell; use host or target shell separately.',
          ],
        ),
      ],
    );
  }

  @override
  CockpitResolvedSystemControlCommand resolveCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return const CockpitResolvedSystemControlCommand.error(
      code: 'systemActionBlocked',
      message:
          'Browser system actions require an active browser bridge; use Flutter or browser-specific target tools.',
    );
  }
}

final class CockpitUnsupportedSystemControlAdapter
    implements CockpitSystemControlAdapter {
  const CockpitUnsupportedSystemControlAdapter(this.platform);

  @override
  final String platform;

  @override
  CockpitSystemControlProfile describe(
    CockpitSystemControlTargetContext target,
  ) {
    return CockpitSystemControlProfile(
      platform: platform,
      deviceId: target.deviceId,
      appId: target.appId,
      processId: target.processId,
      adapter: 'unsupported',
      preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
      fallbackOrder: const <CockpitPlaneKind>[
        CockpitPlaneKind.flutterSemanticPlane,
        CockpitPlaneKind.hostPlane,
      ],
      recommendedNextStep: 'useFlutterOrHostFallback',
      capabilities: CockpitSystemControlAction.values
          .map(
            (action) => CockpitSystemControlCapability(
              action: action,
              plane: CockpitPlaneKind.hostPlane,
              availability: CockpitSystemControlAvailability.unsupported,
              strategy: 'unsupported',
              limitations: <String>['No system control adapter for $platform'],
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  CockpitResolvedSystemControlCommand resolveCommand(
    CockpitSystemControlActionRequest request,
  ) {
    return CockpitResolvedSystemControlCommand.error(
      code: 'unsupportedPlatform',
      message: 'No system control adapter for $platform.',
    );
  }
}
