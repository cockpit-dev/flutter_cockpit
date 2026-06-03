import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../system_control/cockpit_system_control_action_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

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
            'Platform app id or bundle id for window-scoped desktop evidence actions.',
      )
      ..addOption(
        'process-id',
        help:
            'Process id for window-scoped desktop evidence actions when app id is ambiguous.',
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
      ..addOption('text', help: 'Text for typeText.')
      ..addOption('url', help: 'URL for openUrl.')
      ..addOption('package-id', help: 'Package id for grantPermission.')
      ..addOption('permission', help: 'Permission name for grantPermission.')
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
      'Prefer explicit flags for common actions: --x/--y for tap, --text for typeText, --url for openUrl, --output-path for capture/recording, repeated --arg for runShell. Use --parameters-json only for less common payloads.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools run-system-action --platform android --device-id emulator-5554 --action tap --x 120 --y 240';

  @override
  String get helpWrites =>
      'A bounded action result with availability, success, command, exitCode, errors, requirements, and next step.';

  @override
  Future<int> run() async {
    final platform =
        argResults?['platform'] as String? ??
        cockpitReadLaunchPlatform(argResults, usage);
    final actionValue = argResults?['action'] as String?;
    if (actionValue == null || actionValue.isEmpty) {
      throw UsageException('--action is required.', usage);
    }
    final parameters = await _readParameters();
    final result = await _runAction(
      CockpitSystemControlActionRequest(
        platform: platform,
        deviceId: argResults?['device-id'] as String?,
        appId: argResults?['app-id'] as String?,
        processId: cockpitReadOptionalPositiveInt(
          argResults,
          'process-id',
          usage,
        ),
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
    addString('url', 'url');
    addString('package-id', 'packageId');
    addString('permission', 'permission');
    addString('output-path', 'outputPath');
    addString('name', 'name');
    addString('purpose', 'purpose');
    final args = argResults?['arg'] as List<String>? ?? const <String>[];
    if (args.isNotEmpty) {
      parameters['command'] = args;
    }
    return parameters;
  }
}
