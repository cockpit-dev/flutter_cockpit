import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_launch_target_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_flutter_launch_configuration_cli.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitLaunchTargetCliFunction =
    Future<CockpitLaunchTargetResult> Function(
      CockpitLaunchTargetRequest request,
    );

final class LaunchTargetCommand extends CockpitCliCommand {
  LaunchTargetCommand({
    CockpitLaunchTargetService? service,
    CockpitLaunchTargetCliFunction? launch,
    StringSink? stdoutSink,
  }) : _launch = launch ?? (service ?? CockpitLaunchTargetService()).launch,
       _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('project-dir', help: 'Project directory to launch from.')
      ..addOption('target', help: 'Optional Dart entrypoint.')
      ..addOption(
        'flavor',
        help:
            'Optional Flutter flavor / Xcode scheme to build and run for the target-first loop.',
      )
      ..addOption(
        'platform',
        help:
            'Target platform such as android, ios, macos, windows, linux, or web.',
      )
      ..addOption(
        'device-id',
        help:
            'Device, browser, or host target identifier. Required for android, ios, and web; desktop defaults to the platform.',
      )
      ..addOption(
        'session-port',
        defaultsTo: '57331',
        help:
            'Target-side cockpit port or browser bridge port to launch against.',
      )
      ..addOption(
        'target-kind',
        allowed: CockpitTargetKind.values
            .map((targetKind) => targetKind.name)
            .toList(growable: false),
        defaultsTo: CockpitTargetKind.flutterApp.name,
        help: 'Normalized target kind to persist in target.json.',
      )
      ..addOption(
        'mode',
        allowed: CockpitAppMode.values
            .map((mode) => mode.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitAppMode.development.jsonValue,
        help:
            'Launch mode: development keeps reload support when available; automation favors clean target sessions. Web target-first loops also use development mode.',
      )
      ..addOption(
        'launch-timeout-seconds',
        defaultsTo: '120',
        help:
            'Total time budget for build, launch, and ready checks on the target loop.',
      )
      ..addOption(
        'target-json',
        help:
            'Optional path where the normalized target handle JSON is written. Persist this when later target-first reads must reopen the same surface.',
      );
    cockpitAddFlutterLaunchConfigurationOptions(argParser);
  }

  final CockpitLaunchTargetCliFunction _launch;
  final StringSink _stdoutSink;

  @override
  String get name => 'launch-target';

  @override
  String get description =>
      'Launch a target-first session and write a normalized target handle.';

  @override
  String get summary => 'Start one target and write target.json.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use at the start of a target-first loop when browser, desktop, mixed-system, or host-controlled surface truth matters more than a plain app handle.';

  @override
  String get helpNeeds =>
      'project-dir defaults to the current directory and platform defaults to the host desktop platform when available. Pass --platform and --device-id for android, ios, or web. target is optional when cockpit/main.dart or lib/main.dart exists. If --target-json is omitted, the target handle is written to the default latest_target.json path.';

  @override
  String get helpExample =>
      'cockpit launch-target --platform web --device-id chrome --output /tmp/launch_target.json --output-format json';

  @override
  String get helpWrites =>
      'The command result JSON plus a normalized target handle at --target-json or .dart_tool/flutter_cockpit/latest_target.json. The full launch result includes the embedded .app handle for later extraction.';

  @override
  Future<int> run() async {
    final platform = cockpitReadLaunchPlatform(argResults, usage);
    final result = await _launch(
      CockpitLaunchTargetRequest(
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
        targetKind: CockpitTargetKind.fromJson(
          _readRequiredOption('target-kind'),
        ),
        mode: CockpitAppMode.fromJson(_readRequiredOption('mode')),
        launchTimeout: Duration(
          seconds:
              cockpitReadOptionalPositiveInt(
                argResults,
                'launch-timeout-seconds',
                usage,
              ) ??
              120,
        ),
        targetHandlePath:
            _readOptionalOption('target-json') ??
            cockpitDefaultTargetHandlePath(),
        launchConfiguration: cockpitReadFlutterLaunchConfiguration(
          argResults,
          usage,
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
