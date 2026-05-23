import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_launch_remote_session_service.dart';
import '../../session/cockpit_remote_session_launcher.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

final class LaunchRemoteSessionCommand extends CockpitCliCommand {
  LaunchRemoteSessionCommand({
    CockpitLaunchRemoteSessionService? service,
    CockpitRemoteSessionLauncher? launcher,
    StringSink? stdoutSink,
  })  : _service =
            service ?? CockpitLaunchRemoteSessionService(launcher: launcher),
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('project-dir', help: 'Flutter project directory to launch.')
      ..addOption(
        'target',
        help:
            'Optional Dart entrypoint. When omitted, flutter_cockpit_devtools tries cockpit/main.dart first, then lib/main.dart.',
      )
      ..addOption(
        'platform',
        help: 'Target platform for the launch.',
        allowed: const <String>['android', 'ios', 'macos', 'windows', 'linux'],
      )
      ..addOption(
        'android-device-id',
        help: 'Android emulator or device ID for bootstrap.',
      )
      ..addOption(
        'ios-device-id',
        help: 'iOS Simulator device ID for bootstrap.',
      )
      ..addOption(
        'session-port',
        help: 'Preferred remote session port.',
        defaultsTo: '47331',
      )
      ..addOption(
        'launch-timeout-seconds',
        help: 'How long to wait for remote health.',
        defaultsTo: '120',
      )
      ..addOption(
        'session-json',
        help:
            'Optional path where the reusable remote session handle JSON should be written.',
      );
  }

  final CockpitLaunchRemoteSessionService _service;
  final StringSink _stdoutSink;

  @override
  String get name => 'launch-remote-session';

  @override
  String get description =>
      'Build, install, and launch a Flutter app until its flutter_cockpit remote session is reachable.';

  @override
  String get summary => 'Launch a direct remote session.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use for low-level remote-session loops when app-first launch-app is too opinionated.';

  @override
  String get helpNeeds =>
      'project-dir defaults to the current directory and platform defaults to the host desktop platform when available. Pass --platform plus the required mobile device ID for android or ios.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools launch-remote-session --platform android --android-device-id emulator-5554';

  @override
  String get helpWrites =>
      'The command result. Use --session-json for the reusable handle, --output for the full result file, or --stdout-format json for jq.';

  @override
  Future<int> run() async {
    final platform = cockpitReadLaunchPlatform(
      argResults,
      usage,
      allowedPlatforms: const <String>{
        'android',
        'ios',
        'macos',
        'windows',
        'linux',
      },
    );
    final result = await _service.launch(
      CockpitLaunchRemoteSessionRequest(
        projectDir: cockpitReadProjectDirOption(argResults),
        target: _readOptionalOption('target'),
        platform: platform,
        deviceId: _resolveDeviceId(platform),
        sessionPort: cockpitReadRequiredPortOption(
          argResults,
          'session-port',
          usage,
        ),
        launchTimeout: Duration(
          seconds: cockpitReadOptionalPositiveInt(
                argResults,
                'launch-timeout-seconds',
                usage,
              ) ??
              120,
        ),
        persistHandlePath: _readOptionalOption('session-json') ??
            cockpitDefaultRemoteSessionHandlePath(),
      ),
    );

    await cockpitWriteJsonPayload(
      payload: <String, Object?>{
        'sessionHandle': result.sessionHandle.toJson(),
        'health': result.health.toJson(),
        if (result.persistedHandlePath != null)
          'persistedHandlePath': result.persistedHandlePath,
      },
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }

  String _resolveDeviceId(String platform) {
    final androidDeviceId = argResults?['android-device-id'] as String?;
    final iosDeviceId = argResults?['ios-device-id'] as String?;

    return switch (platform) {
      'android' when androidDeviceId != null && androidDeviceId.isNotEmpty =>
        androidDeviceId,
      'ios' when iosDeviceId != null && iosDeviceId.isNotEmpty => iosDeviceId,
      'macos' => 'macos',
      'windows' => 'windows',
      'linux' => 'linux',
      'android' => throw UsageException(
          '--android-device-id is required when --platform=android.',
          usage,
        ),
      'ios' => throw UsageException(
          '--ios-device-id is required when --platform=ios.',
          usage,
        ),
      _ => throw UsageException('Unsupported platform: $platform', usage),
    };
  }

  String? _readOptionalOption(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
