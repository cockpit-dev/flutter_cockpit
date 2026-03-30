import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_launch_app_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitLaunchAppFunction = Future<CockpitLaunchAppResult> Function(
  CockpitLaunchAppRequest request,
);

final class LaunchAppCommand extends Command<int> {
  LaunchAppCommand({
    CockpitLaunchAppService? service,
    CockpitLaunchAppFunction? launch,
    StringSink? stdoutSink,
  })  : _launch = launch ?? (service ?? CockpitLaunchAppService()).launch,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('project-dir')
      ..addOption('target')
      ..addOption('platform')
      ..addOption('device-id')
      ..addOption('session-port', defaultsTo: '57331')
      ..addOption(
        'mode',
        allowed: CockpitAppMode.values
            .map((mode) => mode.jsonValue)
            .toList(growable: false),
        defaultsTo: CockpitAppMode.development.jsonValue,
      )
      ..addOption('app-json')
      ..addOption('output-json');
  }

  final CockpitLaunchAppFunction _launch;
  final StringSink _stdoutSink;

  @override
  String get name => 'launch-app';

  @override
  String get description =>
      'Launch a Flutter app for development or automation and emit a normalized app handle.';

  @override
  Future<int> run() async {
    final result = await _launch(
      CockpitLaunchAppRequest(
        projectDir: _readRequiredOption('project-dir'),
        target: _readRequiredOption('target'),
        platform: _readRequiredOption('platform'),
        deviceId: _readDeviceId(),
        sessionPort: int.parse(_readRequiredOption('session-port')),
        mode: CockpitAppMode.fromJson(_readRequiredOption('mode')),
        appHandlePath: argResults?['app-json'] as String?,
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
}
