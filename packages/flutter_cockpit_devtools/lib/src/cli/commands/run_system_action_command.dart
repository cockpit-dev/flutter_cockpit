import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_app_handle.dart';
import '../../system_control/cockpit_system_control_action_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';
import '../cockpit_system_control_cli_support.dart';

final class RunSystemActionCommand extends CockpitCliCommand {
  RunSystemActionCommand({
    CockpitSystemControlActionService? service,
    CockpitSystemControlRunActionFunction? runAction,
    StringSink? stdoutSink,
  }) : _runAction =
           runAction ?? (service ?? CockpitSystemControlActionService()).run,
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'platform',
        allowed: const <String>[
          'android',
          'ios',
          'macos',
          'windows',
          'linux',
          'web',
        ],
        help: 'Target platform from list-targets or read-system-capabilities.',
      )
      ..addOption('device-id', help: 'Device, simulator, or emulator id.')
      ..addOption(
        'app-id',
        help:
            'Platform app id or bundle id for app/window-scoped actions; required for macOS host screenshots and recordings.',
      )
      ..addOption(
        'process-id',
        help:
            'Windows/Linux process id for window-scoped actions when app id is ambiguous.',
      )
      ..addOption('app-json', help: cockpitAppJsonOptionHelp)
      ..addOption(
        'wda-url',
        help:
            'iOS simulator WebDriverAgent endpoint for native UI and system dialog control. Defaults to FLUTTER_COCKPIT_IOS_WDA_URL or probes http://127.0.0.1:8100.',
      )
      ..addOption(
        'action',
        allowed: CockpitSystemControlAction.values
            .map((action) => action.name)
            .toList(growable: false),
        help: 'System control action to run.',
      )
      ..addOption('x', help: 'X coordinate for coordinate actions.')
      ..addOption('y', help: 'Y coordinate for coordinate actions.')
      ..addOption('start-x', help: 'Start X coordinate for drag.')
      ..addOption('start-y', help: 'Start Y coordinate for drag.')
      ..addOption('end-x', help: 'End X coordinate for drag.')
      ..addOption('end-y', help: 'End Y coordinate for drag.')
      ..addOption('duration-ms', help: 'Gesture duration in milliseconds.')
      ..addOption('text', help: 'Text for typeText or setClipboard.')
      ..addOption('key', help: 'Key name for pressKey.')
      ..addOption(
        'decision',
        allowed: const <String>['accept', 'dismiss'],
        help: 'System dialog decision for dismissSystemDialog.',
      )
      ..addOption('url', help: 'URL for openUrl.')
      ..addOption(
        'settings-action',
        help:
            'Platform settings action for openSystemSettings. Android default: android.settings.SETTINGS. iOS default: App-Prefs:.',
      )
      ..addOption(
        'appearance',
        allowed: const <String>['light', 'dark', 'auto'],
        help: 'Appearance mode for setAppearance.',
      )
      ..addOption(
        'content-size',
        help:
            'Content size token for setContentSize, for example large or accessibility-large.',
      )
      ..addOption(
        'font-scale',
        help: 'Android font scale for setContentSize, for example 1.3.',
      )
      ..addOption('latitude', help: 'Latitude for setLocation.')
      ..addOption('longitude', help: 'Longitude for setLocation.')
      ..addOption('altitude', help: 'Optional altitude for setLocation.')
      ..addOption(
        'orientation',
        allowed: const <String>[
          'portrait',
          'landscape',
          'reversePortrait',
          'reverseLandscape',
          'auto',
        ],
        help: 'Orientation for setOrientation.',
      )
      ..addOption(
        'network-speed',
        allowed: const <String>[
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
        help: 'Android emulator network speed for setNetworkSpeed.',
      )
      ..addOption(
        'network-delay',
        allowed: const <String>['gprs', 'edge', 'umts', 'none'],
        help: 'Android emulator network delay for setNetworkDelay.',
      )
      ..addOption('time', help: 'iOS simulator status bar time override.')
      ..addOption(
        'data-network',
        allowed: const <String>[
          'hide',
          'wifi',
          '3g',
          '4g',
          'lte',
          'lte-a',
          'lte+',
          '5g',
          '5g+',
          '5g-uwb',
          '5g-uc',
        ],
        help: 'iOS simulator status bar dataNetwork override.',
      )
      ..addOption(
        'wifi-mode',
        allowed: const <String>['searching', 'failed', 'active'],
        help: 'iOS simulator status bar wifiMode override.',
      )
      ..addOption('wifi-bars', help: 'iOS simulator Wi-Fi bars, 0-3.')
      ..addOption(
        'cellular-mode',
        allowed: const <String>[
          'notSupported',
          'searching',
          'failed',
          'active',
        ],
        help: 'iOS simulator status bar cellularMode override.',
      )
      ..addOption('cellular-bars', help: 'iOS simulator cellular bars, 0-4.')
      ..addOption('operator-name', help: 'iOS simulator carrier name override.')
      ..addOption(
        'battery-state',
        allowed: const <String>['charging', 'charged', 'discharging'],
        help: 'iOS simulator status bar batteryState override.',
      )
      ..addOption('battery-level', help: 'iOS simulator battery level, 0-100.')
      ..addOption('max-depth', help: 'Maximum tree depth for readUiTree.')
      ..addOption('max-nodes', help: 'Maximum tree nodes for readUiTree.')
      ..addOption(
        'package-id',
        help:
            'Android package id for app-scoped actions; use --app-id for iOS bundle ids and desktop targets.',
      )
      ..addOption(
        'app-path',
        help: 'Host path to an app package for installApp.',
      )
      ..addFlag(
        'grant-permissions',
        negatable: false,
        help: 'Grant runtime permissions during Android installApp.',
      )
      ..addFlag(
        'keep-data',
        negatable: false,
        help: 'Keep app data during Android uninstallApp.',
      )
      ..addOption('permission', help: 'Permission name for grantPermission.')
      ..addOption(
        'source-path',
        help:
            'Source path for pushFile, pullFile, or addMedia. For iOS file transfer, relative paths are app data container scoped.',
      )
      ..addOption(
        'destination-path',
        help:
            'Destination path for pushFile or pullFile. For iOS file transfer, relative paths are app data container scoped.',
      )
      ..addOption('title', help: 'Notification title for postNotification.')
      ..addOption('body', help: 'Notification body for postNotification.')
      ..addOption('tag', help: 'Notification tag for postNotification.')
      ..addOption('payload-json', help: 'Platform notification payload JSON.')
      ..addOption('output-path', help: 'Output path for screenshot or video.')
      ..addOption(
        'name',
        help: 'Artifact name for captureScreenshot or startRecording.',
      )
      ..addOption(
        'purpose',
        allowed: const <String>['acceptance', 'repro'],
        help: 'Recording purpose for startRecording.',
      )
      ..addOption(
        'mode',
        allowed: const <String>['auto', 'cheap', 'native', 'full'],
        help: 'Recording mode for startRecording.',
      )
      ..addOption(
        'layer',
        allowed: const <String>[
          'flutter',
          'app-window',
          'host-screen',
          'system',
        ],
        help: 'Recording layer for startRecording.',
      )
      ..addMultiOption('arg', help: 'Repeatable command argument for runShell.')
      ..addOption(
        'parameters-json',
        help:
            'Inline JSON object with action parameters. Explicit flags override matching JSON keys.',
      )
      ..addOption(
        'parameters-file',
        help:
            'Path to a JSON object with action parameters. Explicit flags override matching JSON keys.',
      )
      ..addOption(
        'timeout-seconds',
        defaultsTo: '15',
        help: 'Maximum time before killing the system action process.',
      );
    cockpitAddOutputArgs(argParser);
  }

  final CockpitSystemControlRunActionFunction _runAction;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-system-action';

  @override
  String get description =>
      'Run one Native/System Control Plane action with bounded execution.';

  @override
  String get summary =>
      'Run a system-level action when Flutter semantics are insufficient.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use after read-system-capabilities shows the action is available and Flutter semantic control cannot handle the required system, native, or host surface.';

  @override
  String get helpNeeds =>
      'A platform, action, and the minimal parameters for that action. Device id is required for device-scoped actions such as Android adb or iOS simctl.';

  @override
  String get helpShape =>
      'Prefer explicit flags for common actions: --x/--y for tap, --text for typeText/setClipboard/tapNotification, --key for pressKey, --url for openUrl, --settings-action for openSystemSettings, --appearance, --content-size, --orientation, --network-speed, --network-delay, --time/--battery-level for iOS status bar, --title/--body/--tag or --payload-json for postNotification and tapNotification, --decision for dismissSystemDialog or resolveBlockers, --name/--output-path/--purpose/--mode/--layer for capture and recording, repeated --arg for runShell. Use --parameters-json for blocker recovery, notification tap, or less common payloads.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-system-action --platform android --device-id emulator-5554 --action tap --x 120 --y 240';

  @override
  String get helpWrites =>
      'A bounded action result with availability, success, command, exitCode, errors, requirements, and next step.';

  @override
  Future<int> run() async {
    final app = _readDefaultAppHandle();
    final platform =
        argResults?['platform'] as String? ??
        app?.platform ??
        cockpitReadLaunchPlatform(argResults, usage);
    final actionValue = argResults?['action'] as String?;
    if (actionValue == null || actionValue.isEmpty) {
      throw UsageException('--action is required.', usage);
    }
    final parameters = await _readParameters();
    final appId = await _resolveAppId(app, platform);
    final result = await _runAction(
      CockpitSystemControlActionRequest(
        platform: platform,
        deviceId: argResults?['device-id'] as String? ?? app?.deviceId,
        appId: appId,
        processId:
            cockpitReadOptionalPositiveInt(argResults, 'process-id', usage) ??
            app?.processId,
        metadata: _readMetadata(),
        action: CockpitSystemControlAction.fromJson(actionValue),
        parameters: parameters,
        timeout: Duration(
          seconds:
              cockpitReadOptionalPositiveInt(
                argResults,
                'timeout-seconds',
                usage,
              ) ??
              15,
        ),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }

  CockpitAppHandle? _readDefaultAppHandle() {
    final path = cockpitResolveAppHandlePath(argResults);
    if (path == null || path.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(File(path).readAsStringSync());
      if (decoded is Map<Object?, Object?>) {
        return CockpitAppHandle.fromJson(decoded.cast<String, Object?>());
      }
    } on Object {
      return null;
    }
    return null;
  }

  Future<String?> _resolveAppId(CockpitAppHandle? app, String platform) async {
    return cockpitResolveSystemControlAppId(
      app: app,
      platform: platform,
      explicitAppId: argResults?['app-id'] as String?,
    );
  }

  Map<String, Object?> _readMetadata() {
    final wdaUrl =
        argResults?['wda-url'] as String? ??
        Platform.environment['FLUTTER_COCKPIT_IOS_WDA_URL'];
    if (wdaUrl == null || wdaUrl.trim().isEmpty) {
      return const <String, Object?>{};
    }
    return <String, Object?>{'wdaUrl': wdaUrl.trim()};
  }

  Future<Map<String, Object?>> _readParameters() async {
    final base = await cockpitReadOptionalJsonObject(
      argResults: argResults,
      inlineOption: 'parameters-json',
      fileOption: 'parameters-file',
      label: 'System action parameters',
      usage: usage,
    );
    final parameters = <String, Object?>{...?base};

    void addInt(String option, String key) {
      final value = cockpitReadOptionalInt(argResults, option, usage);
      if (value != null) {
        parameters[key] = value;
      }
    }

    void addString(String option, String key) {
      final value = argResults?[option] as String?;
      if (value != null && value.isNotEmpty) {
        parameters[key] = value;
      }
    }

    addInt('x', 'x');
    addInt('y', 'y');
    addInt('start-x', 'startX');
    addInt('start-y', 'startY');
    addInt('end-x', 'endX');
    addInt('end-y', 'endY');
    addInt('duration-ms', 'durationMs');
    addString('text', 'text');
    addString('key', 'key');
    addString('decision', 'decision');
    addString('url', 'url');
    addString('settings-action', 'settingsAction');
    addString('appearance', 'appearance');
    addString('content-size', 'contentSize');
    addString('font-scale', 'fontScale');
    addString('latitude', 'latitude');
    addString('longitude', 'longitude');
    addString('altitude', 'altitude');
    addString('orientation', 'orientation');
    addString('network-speed', 'networkSpeed');
    addString('network-delay', 'networkDelay');
    addString('time', 'time');
    addString('data-network', 'dataNetwork');
    addString('wifi-mode', 'wifiMode');
    addInt('wifi-bars', 'wifiBars');
    addString('cellular-mode', 'cellularMode');
    addInt('cellular-bars', 'cellularBars');
    addString('operator-name', 'operatorName');
    addString('battery-state', 'batteryState');
    addInt('battery-level', 'batteryLevel');
    addInt('max-depth', 'maxDepth');
    addInt('max-nodes', 'maxNodes');
    addString('package-id', 'packageId');
    addString('app-path', 'appPath');
    if (argResults?['grant-permissions'] == true) {
      parameters['grantPermissions'] = true;
    }
    if (argResults?['keep-data'] == true) {
      parameters['keepData'] = true;
    }
    addString('permission', 'permission');
    addString('source-path', 'sourcePath');
    addString('destination-path', 'destinationPath');
    addString('title', 'title');
    addString('body', 'body');
    addString('tag', 'tag');
    addString('payload-json', 'payloadJson');
    addString('output-path', 'outputPath');
    addString('name', 'name');
    addString('purpose', 'purpose');
    addString('mode', 'mode');
    addString('layer', 'layer');
    final args = argResults?['arg'] as List<String>? ?? const <String>[];
    if (args.isNotEmpty) {
      parameters['command'] = args;
    }
    return parameters;
  }
}
