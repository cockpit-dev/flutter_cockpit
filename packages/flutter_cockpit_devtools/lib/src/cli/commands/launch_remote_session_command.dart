import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_launch_remote_session_service.dart';
import '../../application/cockpit_json_key_normalizer.dart';
import '../../session/cockpit_remote_session_launcher.dart';
import '../cockpit_command_runner.dart';

final class LaunchRemoteSessionCommand extends Command<int> {
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
        'output-json',
        help: 'Optional path where the session handle JSON should be written.',
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
  Future<int> run() async {
    final platform = _readRequiredOption('platform');
    final result = await _service.launch(
      CockpitLaunchRemoteSessionRequest(
        projectDir: _readRequiredOption('project-dir'),
        target: _readOptionalOption('target'),
        platform: platform,
        deviceId: _resolveDeviceId(platform),
        sessionPort: int.parse(_readRequiredOption('session-port')),
        launchTimeout: Duration(
          seconds: int.parse(_readRequiredOption('launch-timeout-seconds')),
        ),
        persistHandlePath: _readOptionalOption('output-json'),
      ),
    );

    final payload = cockpitCompactJsonText(result.sessionHandle.toJson());
    if (result.persistedHandlePath == null) {
      _stdoutSink.writeln(payload);
    }

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
