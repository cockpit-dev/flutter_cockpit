import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../development/cockpit_development_session_handle.dart';
import '../development/cockpit_development_session_status.dart';
import '../development/cockpit_development_session_supervisor_client.dart';
import '../remote/cockpit_android_port_forwarder.dart';
import '../session/cockpit_remote_session_launcher.dart';
import 'cockpit_entrypoint_resolver.dart';

typedef CockpitDevelopmentSessionLauncher
    = Future<CockpitDevelopmentSessionBootstrap> Function(
  CockpitLaunchDevelopmentSessionRequest request,
);
typedef CockpitSupervisorStatusReader
    = Future<CockpitDevelopmentSessionSupervisorResponse> Function(
  Uri supervisorBaseUri,
);
typedef CockpitSupervisorSpawner = Future<CockpitSpawnedDevelopmentSupervisor>
    Function({
  required CockpitLaunchDevelopmentSessionRequest request,
  required String flutterVersion,
  required int hostPort,
  required int supervisorPort,
  required File supervisorLogFile,
});
typedef CockpitDelay = Future<void> Function(Duration duration);

final class CockpitLaunchDevelopmentSessionRequest {
  const CockpitLaunchDevelopmentSessionRequest({
    required this.projectDir,
    required this.platform,
    required this.deviceId,
    required this.sessionPort,
    this.target,
    this.launchTimeout = const Duration(seconds: 120),
    this.persistHandlePath,
  });

  final String projectDir;
  final String? target;
  final String platform;
  final String deviceId;
  final int sessionPort;
  final Duration launchTimeout;
  final String? persistHandlePath;
}

final class CockpitDevelopmentSessionBootstrap {
  const CockpitDevelopmentSessionBootstrap({
    required this.sessionHandle,
    required this.status,
    this.supervisorLogPath,
  });

  final CockpitDevelopmentSessionHandle sessionHandle;
  final CockpitDevelopmentSessionStatus status;
  final String? supervisorLogPath;
}

final class CockpitLaunchDevelopmentSessionResult {
  const CockpitLaunchDevelopmentSessionResult({
    required this.sessionHandle,
    required this.status,
    this.persistedHandlePath,
    this.supervisorLogPath,
  });

  final CockpitDevelopmentSessionHandle sessionHandle;
  final CockpitDevelopmentSessionStatus status;
  final String? persistedHandlePath;
  final String? supervisorLogPath;
}

final class CockpitLaunchDevelopmentSessionService {
  CockpitLaunchDevelopmentSessionService({
    CockpitDevelopmentSessionLauncher? launcher,
    CockpitDevelopmentSessionSupervisorClient? supervisorClient,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    CockpitFlutterVersionReader flutterVersionReader =
        cockpitReadActiveFlutterVersion,
    CockpitEntrypointResolver? entrypointResolver,
  })  : _launcher = launcher ??
            CockpitDevelopmentSessionDaemonLauncher(
              supervisorStatusReader: (supervisorClient ??
                      CockpitDevelopmentSessionSupervisorClient())
                  .readStatus,
              portForwarder: portForwarder,
              flutterVersionReader: flutterVersionReader,
            ).launch,
        _entrypointResolver = entrypointResolver ?? CockpitEntrypointResolver();

  final CockpitDevelopmentSessionLauncher _launcher;
  final CockpitEntrypointResolver _entrypointResolver;

  Future<CockpitLaunchDevelopmentSessionResult> launch(
    CockpitLaunchDevelopmentSessionRequest request,
  ) async {
    final resolvedRequest = CockpitLaunchDevelopmentSessionRequest(
      projectDir: request.projectDir,
      target: _entrypointResolver.resolve(
        projectDir: request.projectDir,
        target: request.target,
      ),
      platform: request.platform,
      deviceId: request.deviceId,
      sessionPort: request.sessionPort,
      launchTimeout: request.launchTimeout,
      persistHandlePath: request.persistHandlePath,
    );
    final bootstrap = await _launcher(resolvedRequest);
    final persistedHandlePath = await _persistHandleIfRequested(
      path: resolvedRequest.persistHandlePath,
      handle: bootstrap.sessionHandle,
    );

    return CockpitLaunchDevelopmentSessionResult(
      sessionHandle: bootstrap.sessionHandle,
      status: bootstrap.status,
      persistedHandlePath: persistedHandlePath,
      supervisorLogPath: bootstrap.supervisorLogPath,
    );
  }

  Future<String?> _persistHandleIfRequested({
    required String? path,
    required CockpitDevelopmentSessionHandle handle,
  }) async {
    if (path == null || path.isEmpty) {
      return null;
    }

    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(handle.toJson()),
    );
    return p.normalize(file.path);
  }
}

final class CockpitSpawnedDevelopmentSupervisor {
  const CockpitSpawnedDevelopmentSupervisor({
    required this.baseUri,
    required this.stop,
    this.logPath,
  });

  final Uri baseUri;
  final Future<void> Function() stop;
  final String? logPath;
}

final class CockpitDevelopmentSessionDaemonLauncher {
  CockpitDevelopmentSessionDaemonLauncher({
    required CockpitSupervisorStatusReader supervisorStatusReader,
    required CockpitAndroidPortForwarder portForwarder,
    required CockpitFlutterVersionReader flutterVersionReader,
    CockpitSupervisorSpawner? spawnSupervisor,
    Future<int> Function()? allocatePort,
    CockpitDelay? delay,
  })  : _supervisorStatusReader = supervisorStatusReader,
        _portForwarder = portForwarder,
        _flutterVersionReader = flutterVersionReader,
        _spawnSupervisor = spawnSupervisor ?? _defaultSpawnSupervisor,
        _allocatePort = allocatePort ?? _defaultAllocatePort,
        _delay = delay ?? Future<void>.delayed;

  final CockpitSupervisorStatusReader _supervisorStatusReader;
  final CockpitAndroidPortForwarder _portForwarder;
  final CockpitFlutterVersionReader _flutterVersionReader;
  final CockpitSupervisorSpawner _spawnSupervisor;
  final Future<int> Function() _allocatePort;
  final CockpitDelay _delay;

  Future<CockpitDevelopmentSessionBootstrap> launch(
    CockpitLaunchDevelopmentSessionRequest request,
  ) async {
    final flutterVersion = await _flutterVersionReader();
    final hostPort = request.platform == 'android'
        ? await _portForwarder.ensureForwarded(
            deviceId: request.deviceId,
            preferredHostPort: request.sessionPort,
            devicePort: request.sessionPort,
          )
        : request.sessionPort;
    final deadline = DateTime.now().add(request.launchTimeout);
    Object? lastFailure;
    CockpitSpawnedDevelopmentSupervisor? activeAttempt;

    while (DateTime.now().isBefore(deadline)) {
      final supervisorPort = await _allocatePort();
      final supervisorLogFile = File(
        p.join(
          Directory.systemTemp.path,
          'flutter_cockpit_development_supervisor_$supervisorPort.log',
        ),
      );
      await supervisorLogFile.parent.create(recursive: true);

      final attempt = await _spawnSupervisor(
        request: request,
        flutterVersion: flutterVersion,
        hostPort: hostPort,
        supervisorPort: supervisorPort,
        supervisorLogFile: supervisorLogFile,
      );
      activeAttempt = attempt;

      final remaining = deadline.difference(DateTime.now());
      final attemptTimeout = remaining;
      final attemptDeadline = DateTime.now().add(attemptTimeout);

      while (DateTime.now().isBefore(attemptDeadline)) {
        try {
          final response = await _supervisorStatusReader(attempt.baseUri);
          if (response.status.state == CockpitDevelopmentSessionState.ready) {
            return CockpitDevelopmentSessionBootstrap(
              sessionHandle: response.sessionHandle,
              status: response.status,
              supervisorLogPath: attempt.logPath,
            );
          }
          if (_isStartupLockContention(response.status.lastError)) {
            lastFailure = StateError(response.status.lastError!);
            break;
          }
          if (response.status.state == CockpitDevelopmentSessionState.failed ||
              response.status.state == CockpitDevelopmentSessionState.stopped) {
            lastFailure = StateError(
              response.status.lastError ??
                  'Development supervisor entered ${response.status.state.jsonValue}.',
            );
            break;
          }
        } on Object catch (error) {
          lastFailure = error;
        }
        await _delay(const Duration(milliseconds: 500));
      }

      lastFailure = await _stopAttempt(
        activeAttempt,
        priorFailure: lastFailure,
      );
      activeAttempt = null;
      if (DateTime.now().isBefore(deadline)) {
        await _delay(const Duration(seconds: 1));
      }
    }

    if (activeAttempt != null) {
      lastFailure = await _stopAttempt(
        activeAttempt,
        priorFailure: lastFailure,
      );
    }
    if (lastFailure != null) {
      throw StateError(
        'Development session did not become ready before timeout: $lastFailure',
      );
    }
    throw TimeoutException(
      'Development session did not become ready before timeout.',
      request.launchTimeout,
    );
  }

  static Future<int> _defaultAllocatePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    try {
      return socket.port;
    } finally {
      await socket.close();
    }
  }

  static Future<CockpitSpawnedDevelopmentSupervisor> _defaultSpawnSupervisor({
    required CockpitLaunchDevelopmentSessionRequest request,
    required String flutterVersion,
    required int hostPort,
    required int supervisorPort,
    required File supervisorLogFile,
  }) async {
    await supervisorLogFile.parent.create(recursive: true);
    final process = await Process.start(
      Platform.resolvedExecutable,
      <String>[
        'run',
        'flutter_cockpit_devtools:flutter_cockpit_development_supervisor',
        '--project-dir',
        request.projectDir,
        '--target',
        request.target!,
        '--platform',
        request.platform,
        '--device-id',
        request.deviceId,
        '--session-port',
        request.sessionPort.toString(),
        '--app-host-port',
        hostPort.toString(),
        '--supervisor-port',
        supervisorPort.toString(),
        '--flutter-version',
        flutterVersion,
        '--launch-timeout-seconds',
        request.launchTimeout.inSeconds.toString(),
      ],
      workingDirectory: request.projectDir,
      mode: ProcessStartMode.detachedWithStdio,
    );
    final baseUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: supervisorPort,
    );
    return CockpitSpawnedDevelopmentSupervisor(
      baseUri: baseUri,
      stop: () async {
        try {
          process.stdin.close();
        } on Object {
          // Ignore shutdown races.
        }
        process.kill(ProcessSignal.sigterm);
        await Future.any(<Future<Object?>>[
          process.exitCode,
          Future<Object?>.delayed(const Duration(milliseconds: 500)),
        ]);
        process.kill(ProcessSignal.sigkill);
        await Future.any(<Future<Object?>>[
          process.exitCode,
          Future<Object?>.delayed(const Duration(milliseconds: 200)),
        ]);
      },
      logPath: p.normalize(supervisorLogFile.path),
    );
  }

  static bool _isStartupLockContention(String? error) {
    if (error == null) {
      return false;
    }
    return error.toLowerCase().contains('startup lock');
  }

  Future<Object?> _stopAttempt(
    CockpitSpawnedDevelopmentSupervisor attempt, {
    required Object? priorFailure,
  }) async {
    try {
      await attempt.stop();
      return priorFailure;
    } on Object catch (error) {
      if (priorFailure != null) {
        return priorFailure;
      }
      return error;
    }
  }
}
