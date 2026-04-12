import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_launch_app_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitLaunchAppFunction = Future<CockpitLaunchAppResult> Function(
  CockpitLaunchAppRequest request,
);

final class LaunchAppCommand extends CockpitCliCommand {
  LaunchAppCommand({
    CockpitLaunchAppService? service,
    CockpitLaunchAppFunction? launch,
    StringSink? stdoutSink,
  })  : _launch = launch ?? (service ?? CockpitLaunchAppService()).launch,
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
        help: 'Target platform: android, ios, macos, windows, or linux.',
      )
      ..addOption(
        'device-id',
        help:
            'Device or emulator ID. Required for mobile; desktop defaults to the platform.',
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
            'Launch mode: development keeps reload support; automation favors clean automation sessions.',
      )
      ..addOption(
        'app-json',
        help:
            'Optional path where the normalized app handle JSON should be written.',
      )
      ..addOption(
        'output-json',
        help:
            'Optional path where the full launch result JSON should be written.',
      );
  }

  final CockpitLaunchAppFunction _launch;
  final StringSink _stdoutSink;

  @override
  String get name => 'launch-app';

  @override
  String get description =>
      'Launch one Flutter app and write a normalized app handle.';

  @override
  String get summary => 'Start one app and write app.json.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use once at the start of an app-first loop or whenever you need a fresh app handle.';

  @override
  String get helpNeeds =>
      'project-dir, platform, and a mobile device ID when the platform is android or ios. target is optional when cockpit/main.dart or lib/main.dart exists.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools launch-app --project-dir examples/cockpit_demo --platform android --device-id emulator-5554 --app-json /tmp/app.json';

  @override
  String get helpWrites =>
      'The command result JSON. The reusable app handle is always written to the current workspace at .dart_tool/flutter_cockpit/latest_app.json, and --app-json can also mirror it elsewhere.';

  @override
  Future<int> run() async {
    final result = await _launch(
      CockpitLaunchAppRequest(
        projectDir: _readRequiredOption('project-dir'),
        target: _readOptionalOption('target'),
        platform: _readRequiredOption('platform'),
        deviceId: _readDeviceId(),
        sessionPort: int.parse(_readRequiredOption('session-port')),
        launchTimeout: Duration(
          seconds: int.parse(_readRequiredOption('launch-timeout-seconds')),
        ),
        mode: CockpitAppMode.fromJson(_readRequiredOption('mode')),
        appHandlePath: (argResults?['app-json'] as String?) ??
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

  String _readDeviceId() {
    final explicit = argResults?['device-id'] as String?;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final platform = _readRequiredOption('platform');
    return switch (platform) {
      'macos' => 'macos',
      'windows' => 'windows',
      'linux' => 'linux',
      _ =>
        throw UsageException('--device-id is required for $platform.', usage),
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
