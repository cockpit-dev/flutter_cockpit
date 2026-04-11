import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_launch_target_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitLaunchTargetCliFunction = Future<CockpitLaunchTargetResult>
    Function(
  CockpitLaunchTargetRequest request,
);

final class LaunchTargetCommand extends CockpitCliCommand {
  LaunchTargetCommand({
    CockpitLaunchTargetService? service,
    CockpitLaunchTargetCliFunction? launch,
    StringSink? stdoutSink,
  })  : _launch = launch ?? (service ?? CockpitLaunchTargetService()).launch,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('project-dir', help: 'Project directory to launch from.')
      ..addOption('target', help: 'Optional Dart entrypoint.')
      ..addOption('platform', help: 'Target platform.')
      ..addOption('device-id', help: 'Device or host target identifier.')
      ..addOption('session-port', defaultsTo: '57331')
      ..addOption(
        'target-kind',
        allowed: CockpitTargetKind.values
            .map((targetKind) => targetKind.name)
            .toList(growable: false),
        defaultsTo: CockpitTargetKind.flutterApp.name,
      )
      ..addOption(
        'mode',
        allowed: CockpitAppMode.values
            .map((mode) => mode.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitAppMode.development.jsonValue,
      )
      ..addOption('launch-timeout-seconds', defaultsTo: '120')
      ..addOption(
        'target-json',
        help:
            'Optional path where the normalized target handle JSON is written.',
      )
      ..addOption('output-json');
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
  Future<int> run() async {
    final result = await _launch(
      CockpitLaunchTargetRequest(
        projectDir: _readRequiredOption('project-dir'),
        target: _readOptionalOption('target'),
        platform: _readRequiredOption('platform'),
        deviceId: _readDeviceId(),
        sessionPort: int.parse(_readRequiredOption('session-port')),
        targetKind: CockpitTargetKind.fromJson(
          _readRequiredOption('target-kind'),
        ),
        mode: CockpitAppMode.fromJson(_readRequiredOption('mode')),
        launchTimeout: Duration(
          seconds: int.parse(_readRequiredOption('launch-timeout-seconds')),
        ),
        targetHandlePath: argResults?['target-json'] as String?,
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
      'web' => 'web',
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
