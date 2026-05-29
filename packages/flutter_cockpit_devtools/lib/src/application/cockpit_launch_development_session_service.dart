import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../development/cockpit_development_session_handle.dart';
import '../development/cockpit_development_session_machine_launcher.dart';
import '../development/cockpit_development_session_status.dart';
import '../development/cockpit_development_session_supervisor_client.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import '../remote/cockpit_android_port_forwarder.dart';
import '../session/cockpit_session_process_runner.dart';
import '../session/cockpit_remote_session_launcher.dart';
import 'cockpit_entrypoint_resolver.dart';
import 'cockpit_compact_json.dart';

typedef CockpitDevelopmentSessionLauncher =
    Future<CockpitDevelopmentSessionBootstrap> Function(
      CockpitLaunchDevelopmentSessionRequest request,
    );
typedef CockpitSupervisorStatusReader =
    Future<CockpitDevelopmentSessionSupervisorResponse> Function(
      Uri supervisorBaseUri,
    );
typedef CockpitSupervisorSpawner =
    Future<CockpitSpawnedDevelopmentSupervisor> Function({
      required CockpitLaunchDevelopmentSessionRequest request,
      required String flutterVersion,
      required String flutterExecutable,
      required String dartExecutable,
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
    this.flavor,
    this.launchTimeout = const Duration(seconds: 120),
    this.persistHandlePath,
  });

  final String projectDir;
  final String? target;
  final String? flavor;
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
    CockpitSupervisorStatusReader? supervisorStatusReader,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    CockpitFlutterVersionReader? flutterVersionReader,
    CockpitFlutterExecutableVersionReader flutterVersionForExecutableReader =
        cockpitReadFlutterVersion,
    Future<String> Function()? flutterExecutableReader,
    Future<String> Function()? dartExecutableReader,
    CockpitSdkEnvironment? sdkEnvironment,
    CockpitEntrypointResolver? entrypointResolver,
    CockpitSupervisorSpawner? spawnSupervisor,
    Future<int> Function()? allocatePort,
    CockpitDelay? delay,
  }) : _launcher =
           launcher ??
           CockpitDevelopmentSessionDaemonLauncher(
             supervisorStatusReader:
                 supervisorStatusReader ??
                 (supervisorClient ??
                         CockpitDevelopmentSessionSupervisorClient())
                     .readStatus,
             portForwarder: portForwarder,
             flutterVersionReader: flutterVersionReader,
             flutterVersionForExecutableReader:
                 flutterVersionForExecutableReader,
             flutterExecutableReader:
                 flutterExecutableReader ??
                 (() async =>
                     (sdkEnvironment ?? CockpitSdkEnvironment.current())
                         .flutterExecutable),
             dartExecutableReader:
                 dartExecutableReader ??
                 (() async =>
                     (sdkEnvironment ?? CockpitSdkEnvironment.current())
                         .dartExecutable),
             spawnSupervisor: spawnSupervisor,
             allocatePort: allocatePort,
             delay: delay,
           ).launch,
       _entrypointResolver = entrypointResolver ?? CockpitEntrypointResolver();

  final CockpitDevelopmentSessionLauncher _launcher;
  final CockpitEntrypointResolver _entrypointResolver;

  Future<CockpitLaunchDevelopmentSessionResult> launch(
    CockpitLaunchDevelopmentSessionRequest request,
  ) async {
    final normalizedProjectDir = cockpitNormalizeProjectDir(request.projectDir);
    final resolvedRequest = CockpitLaunchDevelopmentSessionRequest(
      projectDir: normalizedProjectDir,
      target: _entrypointResolver.resolve(
        projectDir: normalizedProjectDir,
        target: request.target,
      ),
      flavor: request.flavor,
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
    await file.writeAsString(cockpitPrettyJsonText(handle.toJson()));
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
    CockpitFlutterVersionReader? flutterVersionReader,
    CockpitFlutterExecutableVersionReader flutterVersionForExecutableReader =
        cockpitReadFlutterVersion,
    required Future<String> Function() flutterExecutableReader,
    Future<String> Function()? dartExecutableReader,
    CockpitSupervisorSpawner? spawnSupervisor,
    Future<int> Function()? allocatePort,
    CockpitDelay? delay,
  }) : _supervisorStatusReader = supervisorStatusReader,
       _portForwarder = portForwarder,
       _flutterVersionReader = flutterVersionReader,
       _flutterVersionForExecutableReader = flutterVersionForExecutableReader,
       _flutterExecutableReader = flutterExecutableReader,
       _dartExecutableReader =
           dartExecutableReader ?? cockpitResolveActiveDartExecutable,
       _spawnSupervisor = spawnSupervisor ?? _defaultSpawnSupervisor,
       _allocatePort = allocatePort ?? _defaultAllocatePort,
       _delay = delay ?? Future<void>.delayed;

  final CockpitSupervisorStatusReader _supervisorStatusReader;
  final CockpitAndroidPortForwarder _portForwarder;
  final CockpitFlutterVersionReader? _flutterVersionReader;
  final CockpitFlutterExecutableVersionReader
  _flutterVersionForExecutableReader;
  final Future<String> Function() _flutterExecutableReader;
  final Future<String> Function() _dartExecutableReader;
  final CockpitSupervisorSpawner _spawnSupervisor;
  final Future<int> Function() _allocatePort;
  final CockpitDelay _delay;

  Future<CockpitDevelopmentSessionBootstrap> launch(
    CockpitLaunchDevelopmentSessionRequest request,
  ) async {
    final flutterExecutable = await _flutterExecutableReader();
    final flutterVersion = await cockpitResolveFlutterVersionForLaunch(
      flutterExecutable: flutterExecutable,
      legacyFlutterVersionReader: _flutterVersionReader,
      flutterVersionForExecutableReader: _flutterVersionForExecutableReader,
    );
    final dartExecutable = await _dartExecutableReader();
    final hostPort = request.platform == 'android'
        ? await _portForwarder.ensureForwarded(
            deviceId: request.deviceId,
            preferredHostPort: request.sessionPort,
            devicePort: request.sessionPort,
          )
        : request.sessionPort;
    final deadline = DateTime.now().add(request.launchTimeout);
    Object? lastFailure;
    CockpitDevelopmentSessionSupervisorResponse? lastSupervisorResponse;
    CockpitSpawnedDevelopmentSupervisor? activeAttempt;
    CockpitSpawnedDevelopmentSupervisor? lastAttempt;

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
        flutterExecutable: flutterExecutable,
        dartExecutable: dartExecutable,
        hostPort: hostPort,
        supervisorPort: supervisorPort,
        supervisorLogFile: supervisorLogFile,
      );
      activeAttempt = attempt;
      lastAttempt = attempt;

      final remaining = deadline.difference(DateTime.now());
      final attemptTimeout = remaining;
      final attemptDeadline = DateTime.now().add(attemptTimeout);
      var shouldRetryAttempt = false;
      var permanentStartupFailure = false;

      while (DateTime.now().isBefore(attemptDeadline)) {
        try {
          final response = await _supervisorStatusReader(attempt.baseUri);
          lastSupervisorResponse = response;
          if (response.status.state == CockpitDevelopmentSessionState.ready) {
            return CockpitDevelopmentSessionBootstrap(
              sessionHandle: response.sessionHandle,
              status: response.status,
              supervisorLogPath: attempt.logPath,
            );
          }
          if (_isStartupLockContention(response.status.lastError)) {
            lastFailure = StateError(response.status.lastError!);
            shouldRetryAttempt = true;
            break;
          }
          if (response.status.state == CockpitDevelopmentSessionState.failed ||
              response.status.state == CockpitDevelopmentSessionState.stopped) {
            final fallbackFailure = _fallbackExceptionFromStatusError(
              response.status.lastError,
              sessionHandle: response.sessionHandle,
            );
            if (fallbackFailure != null) {
              lastFailure = fallbackFailure;
              permanentStartupFailure = true;
              break;
            }
            final statusFailure = StateError(
              response.status.lastError ??
                  'Development supervisor entered ${response.status.state.jsonValue}.',
            );
            lastFailure = statusFailure;
            if (_isTransientStartupFailure(statusFailure)) {
              shouldRetryAttempt = true;
            } else {
              permanentStartupFailure = true;
            }
            break;
          }
        } on Object catch (error) {
          lastFailure = error;
        }
        await _delay(const Duration(milliseconds: 500));
      }

      if (lastSupervisorResponse != null &&
          lastFailure == null &&
          !permanentStartupFailure &&
          !shouldRetryAttempt) {
        lastFailure = StateError(
          'last supervisor status ${_formatSupervisorStatus(lastSupervisorResponse.status)}',
        );
      }

      lastFailure = await _stopAttempt(
        activeAttempt,
        priorFailure: lastFailure,
      );
      activeAttempt = null;
      if (permanentStartupFailure) {
        if (lastFailure is CockpitDevelopmentSessionFallbackException) {
          throw lastFailure;
        }
        throw StateError(
          await _startupFailureMessageWithDiagnostics(
            'Development session startup failed: $lastFailure',
            attempt,
          ),
        );
      }
      if (!shouldRetryAttempt &&
          lastFailure != null &&
          !_isTransientStartupFailure(lastFailure)) {
        throw StateError(
          await _startupFailureMessageWithDiagnostics(
            'Development session startup failed: $lastFailure',
            attempt,
          ),
        );
      }
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
        await _startupFailureMessageWithDiagnostics(
          'Development session did not become ready before timeout: $lastFailure',
          activeAttempt ?? lastAttempt,
        ),
      );
    }
    throw TimeoutException(
      await _startupFailureMessageWithDiagnostics(
        'Development session did not become ready before timeout.',
        activeAttempt ?? lastAttempt,
      ),
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
    required String flutterExecutable,
    required String dartExecutable,
    required int hostPort,
    required int supervisorPort,
    required File supervisorLogFile,
  }) async {
    await supervisorLogFile.parent.create(recursive: true);
    final supervisorEntrypoint = await _resolveSupervisorEntrypoint();
    final process = await Process.start(
      dartExecutable,
      <String>[
        'run',
        supervisorEntrypoint,
        '--project-dir',
        request.projectDir,
        '--target',
        request.target!,
        if (request.flavor case final flavor?
            when flavor.isNotEmpty) ...<String>['--flavor', flavor],
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
        '--flutter-executable',
        flutterExecutable,
        '--log-file',
        supervisorLogFile.path,
        '--flutter-version',
        flutterVersion,
        '--launch-timeout-seconds',
        request.launchTimeout.inSeconds.toString(),
      ],
      workingDirectory: request.projectDir,
      mode: ProcessStartMode.detached,
      runInShell: cockpitShouldRunExecutableInShell(dartExecutable),
    );
    final baseUri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: supervisorPort,
    );
    return CockpitSpawnedDevelopmentSupervisor(
      baseUri: baseUri,
      stop: () async {
        process.kill(ProcessSignal.sigterm);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        process.kill(ProcessSignal.sigkill);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      },
      logPath: p.normalize(supervisorLogFile.path),
    );
  }

  static Future<String> _resolveSupervisorEntrypoint() async {
    final packageLibUri = await Isolate.resolvePackageUri(
      Uri.parse(
        'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart',
      ),
    );
    if (packageLibUri == null) {
      throw StateError(
        'Unable to resolve flutter_cockpit_devtools package root for the development supervisor.',
      );
    }
    final libPath = p.fromUri(packageLibUri);
    final packageRoot = p.normalize(p.join(p.dirname(libPath), '..'));
    return p.normalize(
      p.join(packageRoot, 'bin', 'flutter_cockpit_development_supervisor.dart'),
    );
  }

  static bool _isStartupLockContention(String? error) {
    if (error == null) {
      return false;
    }
    return error.toLowerCase().contains('startup lock');
  }

  static bool _isTransientStartupFailure(Object failure) {
    final message = '$failure'.toLowerCase();
    return message.contains('connection refused') ||
        message.contains('refused the network connection') ||
        message.contains('connection closed') ||
        message.contains('connection reset') ||
        message.contains('timed out');
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

  Future<String> _startupFailureMessageWithDiagnostics(
    String message,
    CockpitSpawnedDevelopmentSupervisor? attempt,
  ) async {
    final logPath = attempt?.logPath;
    if (logPath == null || logPath.isEmpty) {
      return message;
    }
    final tail = await _readSupervisorLogTail(logPath, maxLines: 80);
    if (tail == null || tail.isEmpty) {
      return '$message {supervisorLogPath: $logPath}';
    }
    return '$message {supervisorLogPath: $logPath, supervisorLogTail: $tail}';
  }

  Future<String?> _readSupervisorLogTail(
    String path, {
    required int maxLines,
  }) async {
    try {
      final lines = await File(path).readAsLines();
      final tail = lines.length <= maxLines
          ? lines
          : lines.sublist(lines.length - maxLines);
      return tail.join('\n');
    } on Object {
      return null;
    }
  }

  static String _formatSupervisorStatus(
    CockpitDevelopmentSessionStatus status,
  ) {
    return 'state=${status.state.jsonValue} '
        'appReachable=${status.appReachable} '
        'remoteSessionReachable=${status.remoteSessionReachable} '
        'reloadGeneration=${status.reloadGeneration}'
        '${status.lastError == null ? '' : ' lastError=${status.lastError}'}';
  }
}

CockpitDevelopmentSessionFallbackException? _fallbackExceptionFromStatusError(
  String? error, {
  CockpitDevelopmentSessionHandle? sessionHandle,
}) {
  if (error == null || !error.startsWith('[')) {
    return null;
  }
  final closingBracketIndex = error.indexOf('] ');
  if (closingBracketIndex <= 1) {
    return null;
  }
  final code = error.substring(1, closingBracketIndex);
  final message = error.substring(closingBracketIndex + 2);
  if (code.isEmpty || message.isEmpty) {
    return null;
  }
  return CockpitDevelopmentSessionFallbackException(
    code: code,
    message: message,
    remoteSessionHandle: sessionHandle?.remoteSessionHandle,
  );
}
