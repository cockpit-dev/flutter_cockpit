import 'dart:async';

import '../remote/cockpit_android_port_forwarder.dart';
import '../session/cockpit_remote_session_handle.dart';
import '../session/cockpit_remote_session_launcher.dart';
import 'cockpit_flutter_run_machine_client.dart';

typedef CockpitDevelopmentMachineClientStarter
    = Future<CockpitFlutterRunMachineClient> Function({
  required String projectDir,
  required String target,
  required String deviceId,
  String? flutterExecutable,
  List<String> extraArgs,
});

final class CockpitLaunchDevelopmentMachineSessionRequest {
  const CockpitLaunchDevelopmentMachineSessionRequest({
    required this.projectDir,
    required this.target,
    required this.platform,
    required this.deviceId,
    required this.sessionPort,
    required this.hostPort,
    required this.launchTimeout,
    required this.flutterVersion,
    this.flutterExecutable,
  });

  final String projectDir;
  final String target;
  final String platform;
  final String deviceId;
  final int sessionPort;
  final int hostPort;
  final Duration launchTimeout;
  final String flutterVersion;
  final String? flutterExecutable;
}

final class CockpitLaunchDevelopmentMachineSessionResult {
  const CockpitLaunchDevelopmentMachineSessionResult({
    required this.machineClient,
    required this.remoteSessionHandle,
  });

  final CockpitFlutterRunMachineClient machineClient;
  final CockpitRemoteSessionHandle remoteSessionHandle;
}

final class CockpitDevelopmentSessionMachineLauncher {
  CockpitDevelopmentSessionMachineLauncher({
    CockpitDevelopmentMachineClientStarter? machineClientStarter,
    CockpitRemoteSessionStatusReader statusReader =
        cockpitReadRemoteSessionStatus,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    Future<void> Function(Duration duration)? delay,
    DateTime Function()? now,
  })  : _machineClientStarter =
            machineClientStarter ?? CockpitFlutterRunMachineClient.start,
        _statusReader = statusReader,
        _portForwarder = portForwarder,
        _delay = delay ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  final CockpitDevelopmentMachineClientStarter _machineClientStarter;
  final CockpitRemoteSessionStatusReader _statusReader;
  final CockpitAndroidPortForwarder _portForwarder;
  final Future<void> Function(Duration duration) _delay;
  final DateTime Function() _now;

  Future<CockpitLaunchDevelopmentMachineSessionResult> launch(
    CockpitLaunchDevelopmentMachineSessionRequest request,
  ) async {
    final machineClient = await startMachineClient(request);
    final remoteSessionHandle = await waitForRemoteSession(
      request: request,
      machineClient: machineClient,
    );

    return CockpitLaunchDevelopmentMachineSessionResult(
      machineClient: machineClient,
      remoteSessionHandle: remoteSessionHandle,
    );
  }

  Future<CockpitFlutterRunMachineClient> startMachineClient(
    CockpitLaunchDevelopmentMachineSessionRequest request,
  ) {
    return _machineClientStarter(
      projectDir: request.projectDir,
      target: request.target,
      deviceId: request.deviceId,
      flutterExecutable: request.flutterExecutable,
      extraArgs: _buildRemoteSessionExtraArgs(request),
    );
  }

  Future<CockpitRemoteSessionHandle> waitForRemoteSession({
    required CockpitLaunchDevelopmentMachineSessionRequest request,
    required CockpitFlutterRunMachineClient machineClient,
  }) async {
    final hostPort = request.platform == 'android'
        ? await _portForwarder.ensureForwarded(
            deviceId: request.deviceId,
            preferredHostPort: request.hostPort,
            devicePort: request.sessionPort,
          )
        : request.hostPort;
    final baseUri = Uri.parse('http://127.0.0.1:$hostPort');
    final deadline = _now().add(request.launchTimeout);
    final status = await cockpitWaitForRemoteSessionReady(
      baseUri: baseUri,
      timeout: _remaining(deadline, request.launchTimeout),
      statusReader: _statusReader,
    );
    final appId = await _waitForMachineAppId(
      machineClient: machineClient,
      deadline: deadline,
    );

    return CockpitRemoteSessionHandle.fromRemoteStatus(
      projectDir: request.projectDir,
      target: request.target,
      deviceId: request.deviceId,
      appId: appId,
      host: '127.0.0.1',
      hostPort: hostPort,
      devicePort: request.sessionPort,
      status: status,
      launchedAt: _now(),
    );
  }

  List<String> _buildRemoteSessionExtraArgs(
    CockpitLaunchDevelopmentMachineSessionRequest request,
  ) {
    return <String>[
      '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
      '--dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1',
      '--dart-define=FLUTTER_PILOT_REMOTE_PORT=${request.sessionPort}',
      '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=${request.flutterVersion}',
    ];
  }

  Future<String> _waitForMachineAppId({
    required CockpitFlutterRunMachineClient machineClient,
    required DateTime deadline,
  }) async {
    while (_now().isBefore(deadline)) {
      final currentAppId = machineClient.currentAppId;
      if (currentAppId != null && currentAppId.isNotEmpty) {
        return currentAppId;
      }
      await _delay(const Duration(milliseconds: 50));
    }
    throw TimeoutException(
      'Flutter run machine session never reported an app.start appId.',
      deadline.difference(_now()),
    );
  }

  Duration _remaining(DateTime deadline, Duration originalTimeout) {
    final remaining = deadline.difference(_now());
    if (remaining <= Duration.zero) {
      throw TimeoutException(
        'Development machine launch timed out before the app became reachable.',
        originalTimeout,
      );
    }
    return remaining;
  }
}
