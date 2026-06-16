import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_launch_development_session_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitLaunchDevelopmentSessionFunction =
    Future<CockpitLaunchDevelopmentSessionResult> Function(
      CockpitLaunchDevelopmentSessionRequest request,
    );

final class LaunchDevelopmentSessionCommand extends CockpitCliCommand {
  LaunchDevelopmentSessionCommand({
    CockpitLaunchDevelopmentSessionService? service,
    CockpitLaunchDevelopmentSessionFunction? launch,
    StringSink? stdoutSink,
  }) : _launch =
           launch ??
           (service ?? CockpitLaunchDevelopmentSessionService()).launch,
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('project-dir', help: 'Flutter project directory to launch.')
      ..addOption(
        'target',
        help:
            'Optional Dart entrypoint. When omitted, cockpit tries cockpit/main.dart first, then lib/main.dart.',
      )
      ..addOption(
        'platform',
        allowed: const <String>['android', 'ios', 'macos', 'windows', 'linux'],
        help: 'Target platform for the development session.',
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
        defaultsTo: '47331',
        help: 'Preferred remote session port for the app-side bridge.',
      )
      ..addOption(
        'launch-timeout-seconds',
        defaultsTo: '120',
        help:
            'Maximum time to wait for the development session to become ready.',
      )
      ..addOption(
        'session-json',
        help:
            'Optional path where the reusable development session handle JSON should be written.',
      )
      ..addOption(
        'app-json',
        help:
            'Optional path where the app handle JSON should be written for app-scoped commands such as start-recording, stop-recording, and run-batch --recording-json.',
      );
  }

  final CockpitLaunchDevelopmentSessionFunction _launch;
  final StringSink _stdoutSink;

  @override
  String get name => 'launch-development-session';

  @override
  String get description =>
      'Launch a long-lived Flutter development session that supports hot reload, probes, recording, and final validation.';

  @override
  String get summary => 'Launch development session.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use for longer edit-reload-probe loops where a persistent supervisor saves setup time. It also writes an app handle so recording commands stay in the flutter_cockpit flow.';

  @override
  String get helpNeeds =>
      'project-dir defaults to the current directory and platform defaults to the host desktop platform when available. Pass --platform plus the required mobile device ID for android or ios.';

  @override
  String get helpExample =>
      'cockpit launch-development-session --platform ios --ios-device-id <simulator-id> --app-json /tmp/app.json';

  @override
  String get helpWrites =>
      'The command result plus app metadata. Use --session-json for reload/probe commands and --app-json for start-recording, stop-recording, run-batch --recording-json, screenshots, logs, and errors.';

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
    final result = await _launch(
      CockpitLaunchDevelopmentSessionRequest(
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
          seconds:
              cockpitReadOptionalPositiveInt(
                argResults,
                'launch-timeout-seconds',
                usage,
              ) ??
              120,
        ),
        persistHandlePath:
            _readOptionalOption('session-json') ??
            cockpitDefaultDevelopmentSessionHandlePath(),
        persistAppHandlePath:
            _readOptionalOption('app-json') ?? cockpitDefaultAppHandlePath(),
      ),
    );

    await cockpitWriteJsonPayload(
      payload: <String, Object?>{
        'sessionHandle': result.sessionHandle.toJson(),
        'app': result.app.toJson(),
        'status': result.status.toJson(),
        if (result.persistedHandlePath != null)
          'persistedHandlePath': result.persistedHandlePath,
        if (result.appJsonPath != null) 'appJsonPath': result.appJsonPath,
        if (result.supervisorLogPath != null)
          'supervisorLogPath': result.supervisorLogPath,
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
