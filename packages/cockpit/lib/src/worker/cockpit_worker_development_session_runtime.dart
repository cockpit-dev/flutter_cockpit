import 'dart:async';

import '../application/cockpit_app_handle.dart';
import '../application/cockpit_application_service_exception.dart';
import '../application/cockpit_entrypoint_resolver.dart';
import '../application/cockpit_launch_development_session_service.dart';
import '../development/cockpit_development_session_handle.dart';
import '../development/cockpit_development_session_machine_launcher.dart';
import '../development/cockpit_development_session_status.dart';
import '../development/cockpit_development_session_supervisor.dart';
import '../foundation/cockpit_ids.dart';
import '../infrastructure/cockpit_sdk_environment.dart';
import '../remote/cockpit_android_port_forwarder.dart';
import '../remote/cockpit_remote_session_client.dart';
import '../session/cockpit_remote_session_launcher.dart';

final class CockpitWorkerDevelopmentSessionSnapshot {
  const CockpitWorkerDevelopmentSessionSnapshot({
    required this.handle,
    required this.status,
  });

  final CockpitDevelopmentSessionHandle handle;
  final CockpitDevelopmentSessionStatus status;
}

final class CockpitWorkerDevelopmentSessionRuntime {
  CockpitWorkerDevelopmentSessionRuntime({
    CockpitDevelopmentSessionMachineLauncher? machineLauncher,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    CockpitEntrypointResolver? entrypointResolver,
    CockpitSdkEnvironment? sdkEnvironment,
    CockpitFlutterExecutableVersionReader flutterVersionReader =
        cockpitReadFlutterVersion,
    CockpitTokenGenerator? tokenGenerator,
    CockpitDevelopmentMachineDiagnosticLogger? logger,
    DateTime Function()? utcNow,
  }) : _portForwarder = portForwarder,
       _machineLauncher =
           machineLauncher ??
           CockpitDevelopmentSessionMachineLauncher(
             portForwarder: portForwarder,
             diagnosticLogger: logger,
           ),
       _entrypointResolver = entrypointResolver ?? CockpitEntrypointResolver(),
       _sdkEnvironment = sdkEnvironment ?? CockpitSdkEnvironment.current(),
       _flutterVersionReader = flutterVersionReader,
       _tokenGenerator = tokenGenerator ?? CockpitSecureTokenGenerator(),
       _logger = logger,
       _utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final CockpitDevelopmentSessionMachineLauncher _machineLauncher;
  final CockpitAndroidPortForwarder _portForwarder;
  final CockpitEntrypointResolver _entrypointResolver;
  final CockpitSdkEnvironment _sdkEnvironment;
  final CockpitFlutterExecutableVersionReader _flutterVersionReader;
  final CockpitTokenGenerator _tokenGenerator;
  final CockpitDevelopmentMachineDiagnosticLogger? _logger;
  final DateTime Function() _utcNow;
  final Map<String, CockpitDevelopmentSessionSupervisor> _sessions =
      <String, CockpitDevelopmentSessionSupervisor>{};

  Future<CockpitLaunchDevelopmentSessionResult> launch(
    CockpitLaunchDevelopmentSessionRequest request,
  ) async {
    final projectDir = cockpitNormalizeProjectDir(request.projectDir);
    final target = _entrypointResolver.resolve(
      projectDir: projectDir,
      target: request.target,
    );
    final developmentSessionId =
        'development_${_tokenGenerator.nextToken(byteLength: 16)}';
    final flutterExecutable = _sdkEnvironment.flutterExecutable;
    final flutterVersion = await _flutterVersionReader(flutterExecutable);
    final hostPort = request.platform == 'android'
        ? await _portForwarder.ensureForwarded(
            deviceId: request.deviceId,
            preferredHostPort: request.sessionPort,
            devicePort: request.sessionPort,
          )
        : request.sessionPort;
    final machineRequest = CockpitLaunchDevelopmentMachineSessionRequest(
      projectDir: projectDir,
      target: target,
      flavor: request.flavor,
      platform: request.platform,
      deviceId: request.deviceId,
      sessionPort: request.sessionPort,
      hostPort: hostPort,
      launchTimeout: request.launchTimeout,
      flutterExecutable: flutterExecutable,
      flutterVersion: flutterVersion,
      launchId: developmentSessionId,
      launchConfiguration: request.launchConfiguration,
    );
    final endpoint = await _machineLauncher.resolveRemoteSessionEndpoint(
      machineRequest,
    );
    final supervisor = CockpitDevelopmentSessionSupervisor(
      initialHandle: CockpitDevelopmentSessionHandle(
        developmentSessionId: developmentSessionId,
        platform: request.platform,
        deviceId: request.deviceId,
        projectDir: projectDir,
        target: target,
        appId: '',
        appBaseUrl: Uri(
          scheme: 'http',
          host: endpoint.publicHost,
          port: hostPort,
        ).toString(),
        supervisorBaseUrl: 'cockpit-worker://development/$developmentSessionId',
        launchedAt: _utcNow(),
        reloadGeneration: 0,
      ),
      machineClient: null,
      remoteReachabilityProbe: (baseUri) => _probe(
        platform: request.platform,
        deviceId: request.deviceId,
        hostPort: hostPort,
        devicePort: request.sessionPort,
        baseUri: baseUri,
        readiness: false,
      ),
      remoteControlReadinessProbe: (baseUri) => _probe(
        platform: request.platform,
        deviceId: request.deviceId,
        hostPort: hostPort,
        devicePort: request.sessionPort,
        baseUri: baseUri,
        readiness: true,
      ),
      logger: _logger == null
          ? null
          : (message) async {
              await _logger(message);
            },
      bindControlPlane: false,
      settleTimeout: request.launchTimeout,
    );
    final deadline = _utcNow().add(request.launchTimeout);
    await supervisor.start();
    try {
      final launched = await _machineLauncher.launchWithLifecycle(
        machineRequest,
        endpoint: endpoint,
        onMachineClientStarted: supervisor.bindMachineClient,
      );
      await supervisor.bindRemoteSession(launched.remoteSessionHandle);
      await supervisor.waitForState(
        CockpitDevelopmentSessionState.ready,
        timeout: _remaining(deadline),
      );
      final snapshot = await _snapshot(supervisor);
      _sessions[developmentSessionId] = supervisor;
      return CockpitLaunchDevelopmentSessionResult(
        sessionHandle: snapshot.handle,
        status: snapshot.status,
        app: CockpitAppHandle.fromDevelopmentSession(snapshot.handle),
      );
    } on Object catch (error) {
      supervisor.reportStartupFailure(error);
      await supervisor.dispose();
      rethrow;
    }
  }

  Future<CockpitWorkerDevelopmentSessionSnapshot> query(
    CockpitDevelopmentSessionHandle handle,
  ) => _snapshot(_require(handle));

  Future<CockpitWorkerDevelopmentSessionSnapshot> reload(
    CockpitDevelopmentSessionHandle handle,
    CockpitDevelopmentReloadMode mode,
  ) async {
    final supervisor = _require(handle);
    await supervisor.reload(mode);
    return _snapshot(supervisor);
  }

  Future<CockpitWorkerDevelopmentSessionSnapshot> stop(
    CockpitDevelopmentSessionHandle handle,
  ) async {
    final supervisor = _require(handle);
    await supervisor.stop();
    _sessions.remove(handle.developmentSessionId);
    return _snapshot(supervisor);
  }

  Future<void> forceStop(CockpitDevelopmentSessionHandle handle) async {
    final supervisor = _sessions.remove(handle.developmentSessionId);
    if (supervisor == null) return;
    await supervisor.stop();
  }

  Future<void> dispose() async {
    final supervisors = _sessions.values.toList(growable: false);
    _sessions.clear();
    for (final supervisor in supervisors) {
      try {
        await supervisor.stop();
      } on Object {
        await supervisor.dispose();
      }
    }
  }

  CockpitDevelopmentSessionSupervisor _require(
    CockpitDevelopmentSessionHandle handle,
  ) =>
      _sessions[handle.developmentSessionId] ??
      (throw const CockpitApplicationServiceException(
        code: 'developmentSessionNotOwned',
        message: 'Development session is not active in this workspace worker.',
      ));

  Future<CockpitWorkerDevelopmentSessionSnapshot> _snapshot(
    CockpitDevelopmentSessionSupervisor supervisor,
  ) async => CockpitWorkerDevelopmentSessionSnapshot(
    handle: await supervisor.currentHandle(),
    status: await supervisor.currentStatus(),
  );

  Future<bool> _probe({
    required String platform,
    required String deviceId,
    required int hostPort,
    required int devicePort,
    required Uri baseUri,
    required bool readiness,
  }) async {
    if (platform == 'android') {
      await _portForwarder.ensureForwarded(
        deviceId: deviceId,
        preferredHostPort: hostPort,
        devicePort: devicePort,
      );
    }
    try {
      final client = CockpitRemoteSessionClient(baseUri: baseUri);
      return readiness ? await client.ready() : await client.ping();
    } on Object {
      return false;
    }
  }

  Duration _remaining(DateTime deadline) {
    final remaining = deadline.difference(_utcNow());
    if (remaining <= Duration.zero) {
      throw TimeoutException('Development session launch timed out.');
    }
    return remaining;
  }
}
