import 'dart:io';

import 'cockpit_android_remote_session_launcher.dart';
import 'cockpit_remote_session_handle.dart';
import 'cockpit_remote_session_launch_options.dart';
import 'cockpit_remote_session_launcher.dart';
import 'cockpit_session_path.dart';

typedef CockpitIosBundleIdResolver = Future<String> Function(
    {required String appBundlePath});

final class CockpitIosSimulatorRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  CockpitIosSimulatorRemoteSessionLauncher({
    CockpitWorkingDirectoryProcessRunner processRunner = _runProcess,
    CockpitIosBundleIdResolver bundleIdResolver = _resolveBundleId,
    CockpitRemoteSessionStatusReader statusReader =
        cockpitReadRemoteSessionStatus,
    CockpitFlutterVersionReader flutterVersionReader =
        cockpitReadActiveFlutterVersion,
    DateTime Function()? now,
  })  : _processRunner = processRunner,
        _bundleIdResolver = bundleIdResolver,
        _statusReader = statusReader,
        _flutterVersionReader = flutterVersionReader,
        _now = now ?? DateTime.now;

  final CockpitWorkingDirectoryProcessRunner _processRunner;
  final CockpitIosBundleIdResolver _bundleIdResolver;
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

    final flutterVersion =
        options.flutterVersion ?? await _flutterVersionReader();
    final flutterExecutable =
        options.flutterExecutable ?? cockpitFlutterExecutable();
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
          '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
          '--dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1',
          '--dart-define=FLUTTER_PILOT_REMOTE_PORT=${options.sessionPort}',
          '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=$flutterVersion',
        ],
        workingDirectory: options.projectDir);

    final pathContext = cockpitSessionPathContext(options.projectDir);
    final appBundlePath = pathContext.join(
      options.projectDir,
      'build',
      'ios',
      'iphonesimulator',
      'Runner.app',
    );
    final bundleId = await _bundleIdResolver(appBundlePath: appBundlePath);

    await _runRequired('xcrun', <String>[
      'simctl',
      'install',
      options.deviceId,
      appBundlePath,
    ]);
    await _runRequired('xcrun', <String>[
      'simctl',
      'launch',
      options.deviceId,
      bundleId,
    ]);

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
    final pathContext = cockpitSessionPathContext(appBundlePath);
    final result = await Process.run('/usr/libexec/PlistBuddy', <String>[
      '-c',
      'Print :CFBundleIdentifier',
      pathContext.join(appBundlePath, 'Info.plist'),
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to resolve iOS bundle identifier from $appBundlePath: ${result.stderr ?? result.stdout}',
      );
    }
    return '${result.stdout}'.trim();
  }
}
