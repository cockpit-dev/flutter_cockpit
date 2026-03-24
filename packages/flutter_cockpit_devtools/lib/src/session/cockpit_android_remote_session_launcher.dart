// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:path/path.dart' as p;

import '../remote/cockpit_android_port_forwarder.dart';
import 'cockpit_remote_session_handle.dart';
import 'cockpit_remote_session_launch_options.dart';
import 'cockpit_remote_session_launcher.dart';

typedef CockpitWorkingDirectoryProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

typedef CockpitAndroidApplicationIdResolver = Future<String> Function({
  required String projectDir,
  required String buildDirectory,
});

final class CockpitAndroidRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  CockpitAndroidRemoteSessionLauncher({
    CockpitWorkingDirectoryProcessRunner processRunner = _runProcess,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    CockpitAndroidApplicationIdResolver applicationIdResolver =
        _resolveAndroidApplicationId,
    CockpitRemoteSessionStatusReader statusReader =
        cockpitReadRemoteSessionStatus,
    CockpitFlutterVersionReader flutterVersionReader =
        cockpitReadActiveFlutterVersion,
    DateTime Function()? now,
  })  : _processRunner = processRunner,
        _portForwarder = portForwarder,
        _applicationIdResolver = applicationIdResolver,
        _statusReader = statusReader,
        _flutterVersionReader = flutterVersionReader,
        _now = now ?? DateTime.now;

  final CockpitWorkingDirectoryProcessRunner _processRunner;
  final CockpitAndroidPortForwarder _portForwarder;
  final CockpitAndroidApplicationIdResolver _applicationIdResolver;
  final CockpitRemoteSessionStatusReader _statusReader;
  final CockpitFlutterVersionReader _flutterVersionReader;
  final DateTime Function() _now;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    if (options.platform != 'android') {
      throw StateError(
        'CockpitAndroidRemoteSessionLauncher only supports android options.',
      );
    }

    final flutterVersion = await _flutterVersionReader();
    await _runRequired(
        'flutter',
        <String>[
          'build',
          'apk',
          '--debug',
          '--target',
          options.target,
          '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
          '--dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1',
          '--dart-define=FLUTTER_PILOT_REMOTE_PORT=${options.sessionPort}',
          '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=$flutterVersion',
        ],
        workingDirectory: options.projectDir);

    final buildDirectory = p.join(options.projectDir, 'build');
    final applicationId = await _applicationIdResolver(
      projectDir: options.projectDir,
      buildDirectory: buildDirectory,
    );
    final apkPath = p.join(
      buildDirectory,
      'app',
      'outputs',
      'flutter-apk',
      'app-debug.apk',
    );

    await _runRequired('adb', <String>[
      '-s',
      options.deviceId,
      'install',
      '-r',
      apkPath,
    ]);

    await _runRequired('adb', <String>[
      '-s',
      options.deviceId,
      'shell',
      'monkey',
      '-p',
      applicationId,
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]);

    final hostPort = await _portForwarder.ensureForwarded(
      deviceId: options.deviceId,
      preferredHostPort: options.sessionPort,
      devicePort: options.sessionPort,
    );
    final baseUri = Uri.parse('http://127.0.0.1:$hostPort');
    final status = await cockpitWaitForRemoteSessionReady(
      baseUri: baseUri,
      timeout: options.launchTimeout,
      statusReader: _statusReader,
    );

    return CockpitRemoteSessionHandle.fromRemoteStatus(
      projectDir: options.projectDir,
      target: options.target,
      deviceId: options.deviceId,
      appId: applicationId,
      host: '127.0.0.1',
      hostPort: hostPort,
      devicePort: options.sessionPort,
      status: status,
      launchedAt: _now(),
    );
  }

  Future<void> _runRequired(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    final result = await _processRunner(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) {
      throw StateError(
        '$executable ${arguments.join(' ')} failed: ${result.stderr ?? result.stdout}',
      );
    }
  }

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
  }

  static Future<String> _resolveAndroidApplicationId({
    required String projectDir,
    required String buildDirectory,
  }) async {
    final candidates = <String>[
      p.join(projectDir, 'android', 'app', 'build.gradle.kts'),
      p.join(projectDir, 'android', 'app', 'build.gradle'),
    ];

    for (final candidate in candidates) {
      final file = File(candidate);
      if (!file.existsSync()) {
        continue;
      }

      final content = await file.readAsString();
      final match = RegExp(
        r'applicationId\s*=\s*"([^"]+)"|applicationId\s+"([^"]+)"',
      ).firstMatch(content);
      if (match != null) {
        return match.group(1) ?? match.group(2)!;
      }
    }

    throw StateError(
      'Unable to resolve Android applicationId from $projectDir/android/app/build.gradle(.kts).',
    );
  }
}
