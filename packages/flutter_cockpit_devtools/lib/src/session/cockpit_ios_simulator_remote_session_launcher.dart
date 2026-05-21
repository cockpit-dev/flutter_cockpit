import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'cockpit_apple_bundle_support.dart';
import 'cockpit_android_remote_session_launcher.dart';
import 'cockpit_remote_session_handle.dart';
import 'cockpit_remote_session_launch_options.dart';
import 'cockpit_remote_session_launcher.dart';
import 'cockpit_session_path.dart';

typedef CockpitIosBundleIdResolver = Future<String> Function(
    {required String appBundlePath});
typedef CockpitIosSimulatorAppBundlePathResolver = Future<String> Function({
  required String projectDir,
  String? flavor,
});

final class CockpitIosSimulatorRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  CockpitIosSimulatorRemoteSessionLauncher({
    CockpitWorkingDirectoryProcessRunner processRunner = _runProcess,
    CockpitIosBundleIdResolver bundleIdResolver = _resolveBundleId,
    CockpitIosSimulatorAppBundlePathResolver appBundlePathResolver =
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
  final CockpitIosBundleIdResolver _bundleIdResolver;
  final CockpitIosSimulatorAppBundlePathResolver _appBundlePathResolver;
  final CockpitRemoteSessionStatusReader _statusReader;
  final CockpitFlutterVersionReader _flutterVersionReader;
  final DateTime Function() _now;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    if (options.platform != 'ios') {
      throw StateError(
        'CockpitIosSimulatorRemoteSessionLauncher only supports ios options.',
      );
    }

    final deadline = _now().add(options.launchTimeout);
    final flutterVersion =
        options.flutterVersion ?? await _flutterVersionReader();
    final flutterExecutable =
        options.flutterExecutable ?? cockpitFlutterExecutable();
    final bindHost = cockpitRemoteBindHostForPlatform(options.platform);
    await _runRequired(
      flutterExecutable,
      <String>[
        'build',
        'ios',
        '--simulator',
        '--debug',
        '--no-codesign',
        '--target',
        options.target,
        if (options.flavor case final flavor?
            when flavor.isNotEmpty) ...<String>['--flavor', flavor],
        '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_PILOT_REMOTE_HOST=$bindHost',
        '--dart-define=FLUTTER_PILOT_REMOTE_PORT=${options.sessionPort}',
        '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=$flutterVersion',
      ],
      workingDirectory: options.projectDir,
      timeout: _remaining(deadline),
    );

    final appBundlePath = await _appBundlePathResolver(
      projectDir: options.projectDir,
      flavor: options.flavor,
    ).timeout(
      _remaining(deadline),
      onTimeout: () => throw TimeoutException(
        'Resolving iOS simulator app bundle path timed out.',
        _remaining(deadline),
      ),
    );
    final bundleId = await _bundleIdResolver(
      appBundlePath: appBundlePath,
    ).timeout(
      _remaining(deadline),
      onTimeout: () => throw TimeoutException(
        'Resolving iOS simulator bundle identifier timed out.',
        _remaining(deadline),
      ),
    );

    await _runRequired(
        'xcrun',
        <String>[
          'simctl',
          'install',
          options.deviceId,
          appBundlePath,
        ],
        timeout: _remaining(deadline));
    await _runRequired(
        'xcrun',
        <String>[
          'simctl',
          'launch',
          options.deviceId,
          bundleId,
        ],
        timeout: _remaining(deadline));

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

  Future<void> _runRequired(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    required Duration timeout,
  }) async {
    final result = await _processRunner(
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
        'iOS simulator remote session launch timed out before the next stage could start.',
      );
    }
    return remaining;
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
  }) =>
      cockpitResolveIosBundleId(appBundlePath: appBundlePath);

  static Future<String> _resolveAppBundlePath({
    required String projectDir,
    String? flavor,
  }) async {
    final pathContext = cockpitSessionPathContext(projectDir);
    final buildDirectory = Directory(
      pathContext.join(projectDir, 'build', 'ios', 'iphonesimulator'),
    );
    if (!buildDirectory.existsSync()) {
      throw StateError(
        'Unable to locate iOS simulator build output at ${buildDirectory.path}.',
      );
    }
    return _selectBestAppBundlePath(
      buildDirectory: buildDirectory,
      flavor: flavor,
      pathContext: pathContext,
      platformLabel: 'iOS simulator',
    );
  }
}

String _selectBestAppBundlePath({
  required Directory buildDirectory,
  required String? flavor,
  required p.Context pathContext,
  required String platformLabel,
}) {
  return cockpitSelectBestAppBundlePath(
    searchRoot: buildDirectory,
    flavor: flavor,
    pathContext: pathContext,
    platformLabel: platformLabel,
  );
}
