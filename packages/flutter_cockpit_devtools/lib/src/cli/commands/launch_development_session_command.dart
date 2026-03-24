import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_launch_development_session_service.dart';
import '../cockpit_command_runner.dart';

typedef CockpitLaunchDevelopmentSessionFunction
    = Future<CockpitLaunchDevelopmentSessionResult> Function(
  CockpitLaunchDevelopmentSessionRequest request,
);

final class LaunchDevelopmentSessionCommand extends Command<int> {
  LaunchDevelopmentSessionCommand({
    CockpitLaunchDevelopmentSessionService? service,
    CockpitLaunchDevelopmentSessionFunction? launch,
    StringSink? stdoutSink,
  })  : _launch = launch ??
            (service ?? CockpitLaunchDevelopmentSessionService()).launch,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('project-dir', help: 'Flutter project directory to launch.')
      ..addOption(
        'target',
        defaultsTo: 'lib/main.dart',
        help: 'Target Dart entrypoint to launch in development mode.',
      )
      ..addOption(
        'platform',
        allowed: const <String>[
          'android',
          'ios',
          'macos',
          'windows',
          'linux',
        ],
        help: 'Target platform for the development session.',
      )
      ..addOption('android-device-id')
      ..addOption('ios-device-id')
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
        'output-json',
        help:
            'Optional path where the development session handle JSON is written.',
      );
  }

  final CockpitLaunchDevelopmentSessionFunction _launch;
  final StringSink _stdoutSink;

  @override
  String get name => 'launch-development-session';

  @override
  String get description =>
      'Launch a long-lived Flutter development session that supports hot reload, probes, and final validation.';

  @override
  Future<int> run() async {
    final platform = _readRequiredOption('platform');
    final result = await _launch(
      CockpitLaunchDevelopmentSessionRequest(
        projectDir: _readRequiredOption('project-dir'),
        target: _readRequiredOption('target'),
        platform: platform,
        deviceId: _resolveDeviceId(platform),
        sessionPort: int.parse(_readRequiredOption('session-port')),
        launchTimeout: Duration(
          seconds: int.parse(_readRequiredOption('launch-timeout-seconds')),
        ),
        persistHandlePath: _readOptionalOption('output-json'),
      ),
    );

    _stdoutSink.writeln(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'sessionHandle': result.sessionHandle.toJson(),
        'status': result.status.toJson(),
        'persistedHandlePath': result.persistedHandlePath,
      }),
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
