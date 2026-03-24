import 'dart:io';

import 'package:path/path.dart' as p;

import 'cockpit_android_remote_session_launcher.dart';
import 'cockpit_remote_session_handle.dart';
import 'cockpit_remote_session_launch_options.dart';
import 'cockpit_remote_session_launcher.dart';

typedef CockpitMacosBundleIdResolver = Future<String> Function({
  required String appBundlePath,
});

typedef CockpitMacosAppBundlePathResolver = Future<String> Function({
  required String projectDir,
});

final class CockpitMacosRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  CockpitMacosRemoteSessionLauncher({
    CockpitWorkingDirectoryProcessRunner processRunner = _runProcess,
    CockpitMacosBundleIdResolver bundleIdResolver = _resolveBundleId,
    CockpitMacosAppBundlePathResolver appBundlePathResolver =
        _resolveAppBundlePath,
    CockpitRemoteSessionStatusReader statusReader =
        cockpitReadRemoteSessionStatus,
    CockpitFlutterVersionReader flutterVersionReader =
        cockpitReadActiveFlutterVersion,
    DateTime Function()? now,
  })  : _processRunner = processRunner,
        _bundleIdResolver = bundleIdResolver,
        _appBundlePathResolver = appBundlePathResolver,
        _statusReader = statusReader,
        _flutterVersionReader = flutterVersionReader,
        _now = now ?? DateTime.now;

  final CockpitWorkingDirectoryProcessRunner _processRunner;
  final CockpitMacosBundleIdResolver _bundleIdResolver;
  final CockpitMacosAppBundlePathResolver _appBundlePathResolver;
  final CockpitRemoteSessionStatusReader _statusReader;
  final CockpitFlutterVersionReader _flutterVersionReader;
  final DateTime Function() _now;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    if (options.platform != 'macos') {
      throw StateError(
        'CockpitMacosRemoteSessionLauncher only supports macos options.',
      );
    }

    final flutterVersion = await _flutterVersionReader();
    await _runRequired(
      'flutter',
      <String>[
        'build',
        'macos',
        '--debug',
        '--target',
        options.target,
        '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1',
        '--dart-define=FLUTTER_PILOT_REMOTE_PORT=${options.sessionPort}',
        '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=$flutterVersion',
      ],
      workingDirectory: options.projectDir,
    );

    final appBundlePath = await _appBundlePathResolver(
      projectDir: options.projectDir,
    );
    final bundleId = await _bundleIdResolver(appBundlePath: appBundlePath);

    await _runRequired('open', <String>['-n', appBundlePath]);

    final baseUri = Uri.parse('http://127.0.0.1:${options.sessionPort}');
    final status = await cockpitWaitForRemoteSessionReady(
      baseUri: baseUri,
      timeout: options.launchTimeout,
      statusReader: _statusReader,
    );

    return CockpitRemoteSessionHandle.fromRemoteStatus(
      projectDir: options.projectDir,
      target: options.target,
      deviceId: options.deviceId,
      appId: bundleId,
      host: '127.0.0.1',
      hostPort: options.sessionPort,
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

  static Future<String> _resolveBundleId({
    required String appBundlePath,
  }) async {
    final result = await Process.run('/usr/libexec/PlistBuddy', <String>[
      '-c',
      'Print :CFBundleIdentifier',
      p.join(appBundlePath, 'Contents', 'Info.plist'),
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to resolve macOS bundle identifier from $appBundlePath: ${result.stderr ?? result.stdout}',
      );
    }
    return '${result.stdout}'.trim();
  }

  static Future<String> _resolveAppBundlePath({
    required String projectDir,
  }) async {
    final productsDirectory = Directory(
      p.join(projectDir, 'build', 'macos', 'Build', 'Products', 'Debug'),
    );
    if (!productsDirectory.existsSync()) {
      throw StateError(
        'Unable to locate macOS build products at ${productsDirectory.path}.',
      );
    }

    final appBundle =
        productsDirectory.listSync().whereType<Directory>().firstWhere(
              (entry) => entry.path.endsWith('.app'),
              orElse: () => throw StateError(
                'Unable to locate a macOS .app bundle in ${productsDirectory.path}.',
              ),
            );
    return appBundle.path;
  }
}
