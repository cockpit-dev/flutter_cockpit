import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_launch_app_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitLaunchAppFunction =
    Future<CockpitLaunchAppResult> Function(CockpitLaunchAppRequest request);

final class LaunchAppCommand extends CockpitCliCommand {
  LaunchAppCommand({
    CockpitLaunchAppService? service,
    CockpitLaunchAppFunction? launch,
    StringSink? stdoutSink,
  }) : _launch = launch ?? (service ?? CockpitLaunchAppService()).launch,
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('project-dir', help: 'Flutter project directory to launch.')
      ..addOption(
        'target',
        help:
            'Optional Dart entrypoint. When omitted, flutter_cockpit_devtools tries cockpit/main.dart first, then lib/main.dart.',
      )
      ..addOption(
        'flavor',
        help:
            'Optional Flutter flavor / Xcode scheme to build and run. Use this for consumer apps that do not launch through the default flavor.',
      )
      ..addOption(
        'platform',
        help: 'Target platform: android, ios, macos, windows, linux, or web.',
      )
      ..addOption(
        'device-id',
        help:
            'Device, browser, or emulator ID. Required for android, ios, and web; desktop defaults to the platform.',
      )
      ..addOption(
        'session-port',
        defaultsTo: '57331',
        help:
            'App-side cockpit port. Reuse this when you want a stable baseUrl.',
      )
      ..addOption(
        'launch-timeout-seconds',
        defaultsTo: '120',
        help:
            'Total time budget for build, launch, and ready checks. Increase this on cold builds or slower CI hosts.',
      )
      ..addOption(
        'mode',
        allowed: CockpitAppMode.values
            .map((mode) => mode.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitAppMode.development.jsonValue,
        help:
            'Launch mode: development keeps reload support; automation favors clean automation sessions. Web currently launches through development mode.',
      )
      ..addOption(
        'app-json',
        help:
            'Optional path where the normalized app handle JSON should be written.',
      );
  }

  final CockpitLaunchAppFunction _launch;
  final StringSink _stdoutSink;

  @override
  String get name => 'launch-app';

  @override
  String get description =>
      'Launch one Flutter app, leave its supervisor in the background, and write a normalized app handle.';

  @override
  String get summary => 'Start one app, return when ready, and write app.json.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Default start of most loops. App-first is the lowest-friction path for reload, logs, network reads, screenshots, recordings, and cleanup.';

  @override
  String get helpNeeds =>
      'project-dir defaults to the current directory and platform defaults to the host desktop platform when available. Pass --platform and --device-id for android, ios, or web. target is optional when cockpit/main.dart or lib/main.dart exists. Web currently launches through development mode.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools launch-app --platform android --device-id emulator-5554';

  @override
  String get helpWrites =>
      'The command result JSON. If --app-json is omitted, launch-app writes the reusable app handle to .dart_tool/flutter_cockpit/latest_app.json in the current workspace. When --app-json is provided, that explicit path is written instead. The command returns after the app is ready; the development supervisor keeps logs, reload, and stop control alive in the background.';

  @override
  Future<int> run() async {
    final platform = cockpitReadLaunchPlatform(argResults, usage);
    final result = await _launch(
      CockpitLaunchAppRequest(
        projectDir: cockpitReadProjectDirOption(argResults),
        target: _readOptionalOption('target'),
        flavor: _readOptionalOption('flavor'),
        platform: platform,
        deviceId: _readDeviceId(platform),
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
        mode: CockpitAppMode.fromJson(_readRequiredOption('mode')),
        appHandlePath:
            (argResults?['app-json'] as String?) ??
            cockpitDefaultAppHandlePath(),
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }

  String _readDeviceId(String platform) {
    final explicit = argResults?['device-id'] as String?;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return switch (platform) {
      'macos' => 'macos',
      'windows' => 'windows',
      'linux' => 'linux',
      _ => throw UsageException(
        '--device-id is required for $platform.',
        usage,
      ),
    };
  }

  String _readRequiredOption(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      throw UsageException('--$name is required.', usage);
    }
    return value;
  }

  String? _readOptionalOption(String name) {
    final value = argResults?[name] as String?;
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }
}
