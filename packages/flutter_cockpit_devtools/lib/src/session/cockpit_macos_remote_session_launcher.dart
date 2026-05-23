import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'cockpit_android_remote_session_launcher.dart';
import 'cockpit_apple_bundle_support.dart';
import 'cockpit_remote_session_handle.dart';
import 'cockpit_remote_session_launch_options.dart';
import 'cockpit_remote_session_launcher.dart';
import 'cockpit_session_path.dart';

typedef CockpitMacosBundleIdResolver =
    Future<String> Function({required String appBundlePath});

typedef CockpitMacosAppBundlePathResolver =
    Future<String> Function({required String projectDir, String? flavor});

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
  }) : _processRunner = processRunner,
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

    final deadline = _now().add(options.launchTimeout);
    final flutterVersion =
        options.flutterVersion ?? await _flutterVersionReader();
    final flutterExecutable =
        options.flutterExecutable ?? cockpitFlutterExecutable();
    await _runRequired(
      flutterExecutable,
      <String>[
        'build',
        'macos',
        '--debug',
        '--target',
        options.target,
        if (options.flavor case final flavor?
            when flavor.isNotEmpty) ...<String>['--flavor', flavor],
        '--dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1',
        '--dart-define=FLUTTER_COCKPIT_REMOTE_PORT=${options.sessionPort}',
        '--dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=$flutterVersion',
      ],
      workingDirectory: options.projectDir,
      timeout: _remaining(deadline),
    );

    final appBundlePath = await _appBundlePathResolver(
      projectDir: options.projectDir,
      flavor: options.flavor,
    );
    final bundleId = await _bundleIdResolver(appBundlePath: appBundlePath);
    await _bestEffortStopRunningApp(
      bundleId,
      timeout: _capTimeout(_remaining(deadline), const Duration(seconds: 5)),
    );

    await _runRequired('open', <String>[
      '-n',
      appBundlePath,
    ], timeout: _remaining(deadline));

    final baseUri = Uri.parse('http://127.0.0.1:${options.sessionPort}');
    final status = await cockpitWaitForRemoteSessionReady(
      baseUri: baseUri,
      timeout: _remaining(deadline),
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

  Future<void> _bestEffortStopRunningApp(
    String bundleId, {
    required Duration timeout,
  }) async {
    try {
      await _processRunner('osascript', <String>[
        '-e',
        'tell application id "$bundleId" to quit',
      ]).timeout(timeout);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    } on Object {
      // The app may not be running yet; launch should still continue.
    }
  }

  Future<void> _runRequired(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    required Duration timeout,
  }) async {
    final result =
        await _processRunner(
          executable,
          arguments,
          workingDirectory: workingDirectory,
        ).timeout(
          timeout,
          onTimeout: () => throw TimeoutException(
            '$executable ${arguments.join(' ')} timed out.',
            timeout,
          ),
        );
    if (result.exitCode != 0) {
      throw StateError(
        '$executable ${arguments.join(' ')} failed: ${result.stderr ?? result.stdout}',
      );
    }
  }

  Duration _remaining(DateTime deadline) {
    final remaining = deadline.difference(_now());
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'macOS remote session launch timed out before the next stage could start.',
      );
    }
    return remaining;
  }

  Duration _capTimeout(Duration value, Duration max) {
    return value < max ? value : max;
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

  static Future<String> _resolveBundleId({required String appBundlePath}) =>
      cockpitResolveMacosBundleId(appBundlePath: appBundlePath);

  static Future<String> _resolveAppBundlePath({
    required String projectDir,
    String? flavor,
  }) async {
    final pathContext = cockpitSessionPathContext(projectDir);
    final productsDirectory = Directory(
      pathContext.join(
        projectDir,
        'build',
        'macos',
        'Build',
        'Products',
        'Debug',
      ),
    );
    if (!productsDirectory.existsSync()) {
      throw StateError(
        'Unable to locate macOS build products at ${productsDirectory.path}.',
      );
    }
    return _selectBestMacosAppBundlePath(
      productsDirectory: productsDirectory,
      flavor: flavor,
      pathContext: pathContext,
    );
  }
}

String _selectBestMacosAppBundlePath({
  required Directory productsDirectory,
  required String? flavor,
  required p.Context pathContext,
}) {
  return cockpitSelectBestAppBundlePath(
    searchRoot: productsDirectory,
    flavor: flavor,
    pathContext: pathContext,
    platformLabel: 'macOS',
  );
}
