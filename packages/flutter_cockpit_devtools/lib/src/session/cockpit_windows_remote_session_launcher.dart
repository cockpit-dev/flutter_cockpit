import 'dart:async';
import 'dart:io';

import 'cockpit_android_remote_session_launcher.dart';
import 'cockpit_remote_session_handle.dart';
import 'cockpit_remote_session_launch_options.dart';
import 'cockpit_remote_session_launcher.dart';
import 'cockpit_session_path.dart';

typedef CockpitWindowsAppExecutablePathResolver = Future<String> Function({
  required String projectDir,
});
typedef CockpitDesktopAppStarter = Future<void> Function({
  required String executablePath,
  List<String> arguments,
  String? workingDirectory,
  required Duration timeout,
});

final class CockpitWindowsRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  CockpitWindowsRemoteSessionLauncher({
    CockpitWorkingDirectoryProcessRunner processRunner = _runProcess,
    CockpitWindowsAppExecutablePathResolver appExecutablePathResolver =
        _resolveAppExecutablePath,
    CockpitDesktopAppStarter appStarter = _startBackgroundProcess,
    CockpitRemoteSessionStatusReader statusReader =
        cockpitReadRemoteSessionStatus,
    CockpitFlutterVersionReader flutterVersionReader =
        cockpitReadActiveFlutterVersion,
    DateTime Function()? now,
  })  : _processRunner = processRunner,
        _appExecutablePathResolver = appExecutablePathResolver,
        _appStarter = appStarter,
        _statusReader = statusReader,
        _flutterVersionReader = flutterVersionReader,
        _now = now ?? DateTime.now;

  final CockpitWorkingDirectoryProcessRunner _processRunner;
  final CockpitWindowsAppExecutablePathResolver _appExecutablePathResolver;
  final CockpitDesktopAppStarter _appStarter;
  final CockpitRemoteSessionStatusReader _statusReader;
  final CockpitFlutterVersionReader _flutterVersionReader;
  final DateTime Function() _now;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    if (options.platform != 'windows') {
      throw StateError(
        'CockpitWindowsRemoteSessionLauncher only supports windows options.',
      );
    }

    final deadline = _now().add(options.launchTimeout);
    final flutterVersion = await _flutterVersionReader();
    await _runRequired(
      'flutter',
      <String>[
        'build',
        'windows',
        '--debug',
        '--target',
        options.target,
        '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
        '--dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1',
        '--dart-define=FLUTTER_PILOT_REMOTE_PORT=${options.sessionPort}',
        '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=$flutterVersion',
      ],
      workingDirectory: options.projectDir,
      timeout: _remaining(deadline),
    );

    final executablePath = await _appExecutablePathResolver(
      projectDir: options.projectDir,
    );
    final executablePathContext = cockpitSessionPathContext(executablePath);
    await _appStarter(
      executablePath: executablePath,
      workingDirectory: executablePathContext.dirname(executablePath),
      timeout: _capTimeout(_remaining(deadline), const Duration(seconds: 10)),
    );

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
      appId: executablePathContext.basenameWithoutExtension(executablePath),
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
        'Windows remote session launch timed out before the next stage could start.',
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

  static Future<void> _startBackgroundProcess({
    required String executablePath,
    List<String> arguments = const <String>[],
    String? workingDirectory,
    required Duration timeout,
  }) async {
    final process = await Process.start(
      executablePath,
      arguments,
      workingDirectory: workingDirectory,
    ).timeout(
      timeout,
      onTimeout: () => throw TimeoutException(
        'Launching $executablePath timed out.',
        timeout,
      ),
    );
    // Drain stdio so the desktop app can keep running while health polling waits.
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
  }

  static Future<String> _resolveAppExecutablePath({
    required String projectDir,
  }) async {
    final pathContext = cockpitSessionPathContext(projectDir);
    final outputDirectory = Directory(
      pathContext.join(
        projectDir,
        'build',
        'windows',
        'x64',
        'runner',
        'Debug',
      ),
    );
    if (!outputDirectory.existsSync()) {
      throw StateError(
        'Unable to locate Windows build output at ${outputDirectory.path}.',
      );
    }

    final executables = outputDirectory
        .listSync()
        .whereType<File>()
        .map((entry) => entry.path)
        .where((path) => path.toLowerCase().endsWith('.exe'))
        .toList()
      ..sort();
    if (executables.isEmpty) {
      throw StateError(
        'Unable to locate a Windows executable in ${outputDirectory.path}.',
      );
    }
    return executables.first;
  }
}
