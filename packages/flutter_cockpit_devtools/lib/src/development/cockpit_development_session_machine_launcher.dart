import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart'
    show CockpitRemoteSessionStatus;

import '../remote/cockpit_android_port_forwarder.dart';
import '../platform/ios/cockpit_ios_device_connection.dart';
import '../session/cockpit_apple_bundle_support.dart';
import '../session/cockpit_platform_app_identity.dart';
import '../session/cockpit_remote_session_handle.dart';
import '../session/cockpit_remote_session_launcher.dart';
import '../session/cockpit_session_path.dart';
import 'cockpit_flutter_run_machine_client.dart';

typedef CockpitDevelopmentMachineClientStarter
    = Future<CockpitFlutterRunMachineClient> Function({
  required String projectDir,
  required String target,
  required String deviceId,
  String? flavor,
  String? flutterExecutable,
  List<String> extraArgs,
});
typedef CockpitIosDeviceConnectionResolver = Future<CockpitIosDeviceConnection?>
    Function(String deviceId);
typedef CockpitIosFallbackBundleIdResolver = Future<String> Function({
  required String appBundlePath,
});
typedef CockpitIosFallbackAppBundlePathResolver = Future<String> Function({
  required String projectDir,
  String? flavor,
});
typedef CockpitPlatformAppIdResolver = Future<String?> Function({
  required String projectDir,
  required String platform,
  String? flavor,
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
    this.flavor,
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
  final String? flavor;
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

final class CockpitDevelopmentSessionFallbackException implements Exception {
  const CockpitDevelopmentSessionFallbackException({
    required this.code,
    required this.message,
    this.remoteSessionHandle,
    this.remoteStatus,
  });

  final String code;
  final String message;
  final CockpitRemoteSessionHandle? remoteSessionHandle;
  final CockpitRemoteSessionStatus? remoteStatus;

  @override
  String toString() => 'CockpitDevelopmentSessionFallbackException: $message';
}

final class CockpitDevelopmentSessionMachineLauncher {
  CockpitDevelopmentSessionMachineLauncher({
    CockpitDevelopmentMachineClientStarter? machineClientStarter,
    CockpitRemoteSessionStatusReader statusReader =
        cockpitReadRemoteSessionStatus,
    CockpitAndroidPortForwarder portForwarder =
        const CockpitAndroidPortForwarder(),
    CockpitIosDeviceConnectionResolver? iosDeviceConnectionResolver,
    CockpitIosFallbackBundleIdResolver iosFallbackBundleIdResolver =
        cockpitResolveIosBundleId,
    CockpitIosFallbackAppBundlePathResolver iosFallbackAppBundlePathResolver =
        _resolveIosPhysicalAppBundlePath,
    CockpitPlatformAppIdResolver platformAppIdResolver =
        cockpitResolvePlatformAppId,
    Future<void> Function(Duration duration)? delay,
    DateTime Function()? now,
  })  : _machineClientStarter =
            machineClientStarter ?? CockpitFlutterRunMachineClient.start,
        _statusReader = statusReader,
        _portForwarder = portForwarder,
        _iosDeviceConnectionResolver = iosDeviceConnectionResolver ??
            CockpitIosDeviceConnectionProbe().probe,
        _iosFallbackBundleIdResolver = iosFallbackBundleIdResolver,
        _iosFallbackAppBundlePathResolver = iosFallbackAppBundlePathResolver,
        _platformAppIdResolver = platformAppIdResolver,
        _delay = delay ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  final CockpitDevelopmentMachineClientStarter _machineClientStarter;
  final CockpitRemoteSessionStatusReader _statusReader;
  final CockpitAndroidPortForwarder _portForwarder;
  final CockpitIosDeviceConnectionResolver _iosDeviceConnectionResolver;
  final CockpitIosFallbackBundleIdResolver _iosFallbackBundleIdResolver;
  final CockpitIosFallbackAppBundlePathResolver
      _iosFallbackAppBundlePathResolver;
  final CockpitPlatformAppIdResolver _platformAppIdResolver;
  final Future<void> Function(Duration duration) _delay;
  final DateTime Function() _now;

  Future<CockpitLaunchDevelopmentMachineSessionResult> launch(
    CockpitLaunchDevelopmentMachineSessionRequest request,
  ) async {
    final endpoint = await resolveRemoteSessionEndpoint(request);
    final machineClient = await startMachineClient(
      request,
      endpoint: endpoint,
    );
    final remoteSessionHandle = await waitForRemoteSession(
      request: request,
      machineClient: machineClient,
      endpoint: endpoint,
    );

    return CockpitLaunchDevelopmentMachineSessionResult(
      machineClient: machineClient,
      remoteSessionHandle: remoteSessionHandle,
    );
  }

  Future<CockpitFlutterRunMachineClient> startMachineClient(
    CockpitLaunchDevelopmentMachineSessionRequest request, {
    required CockpitResolvedRemoteSessionEndpoint endpoint,
  }) {
    return _machineClientStarter(
      projectDir: request.projectDir,
      target: request.target,
      deviceId: request.deviceId,
      flavor: request.flavor,
      flutterExecutable: request.flutterExecutable,
      extraArgs: _buildRemoteSessionExtraArgs(
        request,
        endpoint: endpoint,
      ),
    );
  }

  Future<CockpitRemoteSessionHandle> waitForRemoteSession({
    required CockpitLaunchDevelopmentMachineSessionRequest request,
    required CockpitFlutterRunMachineClient machineClient,
    required CockpitResolvedRemoteSessionEndpoint endpoint,
  }) async {
    final hostPort = request.platform == 'android'
        ? await _portForwarder.ensureForwarded(
            deviceId: request.deviceId,
            preferredHostPort: request.hostPort,
            devicePort: request.sessionPort,
          )
        : request.hostPort;
    final publicHost = endpoint.publicHost;
    final baseUri = Uri(scheme: 'http', host: publicHost, port: hostPort);
    final deadline = _now().add(request.launchTimeout);
    final status = await _waitForRemoteStatus(
      request: request,
      machineClient: machineClient,
      baseUri: baseUri,
      deadline: deadline,
    );
    final appId = await (() async {
      try {
        return await _waitForMachineAppId(
          request: request,
          machineClient: machineClient,
          deadline: deadline,
        );
      } on CockpitDevelopmentSessionFallbackException catch (error) {
        if (!_isPhysicalIosDevice(request)) {
          rethrow;
        }
        final remoteSessionHandle =
            await _buildPhysicalIosFallbackRemoteSessionHandle(
          request: request,
          endpoint: endpoint,
          hostPort: hostPort,
          status: status,
        );
        throw CockpitDevelopmentSessionFallbackException(
          code: error.code,
          message: error.message,
          remoteSessionHandle: remoteSessionHandle,
          remoteStatus: status,
        );
      }
    })();
    final platformAppId = await _resolvePlatformAppId(
      request: request,
      status: status,
    );

    return CockpitRemoteSessionHandle.fromRemoteStatus(
      projectDir: request.projectDir,
      target: request.target,
      deviceId: request.deviceId,
      appId: appId,
      platformAppId: platformAppId,
      platformAppIdKnown: platformAppId != null,
      host: publicHost,
      hostPort: hostPort,
      devicePort: request.sessionPort,
      status: status,
      launchedAt: _now(),
    );
  }

  List<String> _buildRemoteSessionExtraArgs(
    CockpitLaunchDevelopmentMachineSessionRequest request, {
    required CockpitResolvedRemoteSessionEndpoint endpoint,
  }) {
    final extraArgs = <String>[
      '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
      '--dart-define=FLUTTER_PILOT_REMOTE_HOST=${endpoint.bindHost}',
      '--dart-define=FLUTTER_PILOT_REMOTE_PORT=${request.sessionPort}',
    ];
    if (request.platform == 'ios' && endpoint.bindHost == '::') {
      extraArgs.addAll(const <String>[
        '--dart-define=FLUTTER_COCKPIT_ENABLE_HTTP_NETWORK_OBSERVER=false',
        '--dart-define=FLUTTER_COCKPIT_ENABLE_RUNTIME_OBSERVER=false',
      ]);
    }
    extraArgs.add(
      '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=${request.flutterVersion}',
    );
    return extraArgs;
  }

  Future<CockpitResolvedRemoteSessionEndpoint> resolveRemoteSessionEndpoint(
    CockpitLaunchDevelopmentMachineSessionRequest request,
  ) async {
    if (request.platform != 'ios') {
      return CockpitResolvedRemoteSessionEndpoint(
        bindHost: cockpitRemoteBindHostForPlatform(request.platform),
        publicHost: cockpitRemotePublicHostForPlatform(request.platform),
      );
    }

    if (cockpitLooksLikeIosSimulatorDeviceId(request.deviceId)) {
      return const CockpitResolvedRemoteSessionEndpoint(
        bindHost: '0.0.0.0',
        publicHost: '127.0.0.1',
      );
    }

    final connection = await _iosDeviceConnectionResolver(request.deviceId);
    if (connection != null && connection.hasReachableTunnel) {
      return CockpitResolvedRemoteSessionEndpoint(
        bindHost: '::',
        publicHost: connection.tunnelIpAddress!,
      );
    }

    throw StateError(
      'Unable to resolve a reachable iOS tunnel address for device '
      '${request.deviceId}. Ensure the device is unlocked, connected, and '
      'developer disk image services are available.',
    );
  }

  Future<String> _waitForMachineAppId({
    required CockpitLaunchDevelopmentMachineSessionRequest request,
    required CockpitFlutterRunMachineClient machineClient,
    required DateTime deadline,
  }) async {
    while (_now().isBefore(deadline)) {
      final currentAppId = machineClient.currentAppId;
      if (currentAppId != null && currentAppId.isNotEmpty) {
        return currentAppId;
      }
      final exitError = _machineExitError(
        request: request,
        machineClient: machineClient,
        remoteSessionReady: true,
      );
      if (exitError != null) {
        throw exitError;
      }
      await _delay(const Duration(milliseconds: 50));
    }
    if (_isPhysicalIosDevice(request)) {
      throw const CockpitDevelopmentSessionFallbackException(
        code: 'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
        message: 'The iOS physical-device remote session became reachable, but '
            'flutter run --machine never reported app.start before timeout. '
            'Automation fallback is safe.',
      );
    }
    throw TimeoutException(
      'Flutter run machine session never reported an app.start appId.',
      deadline.difference(_now()),
    );
  }

  Future<CockpitRemoteSessionStatus> _waitForRemoteStatus({
    required CockpitLaunchDevelopmentMachineSessionRequest request,
    required CockpitFlutterRunMachineClient machineClient,
    required Uri baseUri,
    required DateTime deadline,
    Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    while (true) {
      final remaining = deadline.difference(_now());
      if (remaining <= Duration.zero) {
        break;
      }
      try {
        return await _statusReader(baseUri).timeout(remaining);
      } on Object {
        final exitError = _machineExitError(
          request: request,
          machineClient: machineClient,
          remoteSessionReady: false,
        );
        if (exitError != null && !_isPhysicalIosDevice(request)) {
          throw exitError;
        }
        final retryDelay = deadline.difference(_now());
        if (retryDelay <= Duration.zero) {
          break;
        }
        await _delay(retryDelay < pollInterval ? retryDelay : pollInterval);
      }
    }
    final exitCode = machineClient.lastExitCode;
    final diagnostics = machineClient.recentDiagnosticSummary;
    final suffix = exitCode == null
        ? ''
        : diagnostics.isEmpty
            ? ' after flutter run --machine exited (exitCode=$exitCode)'
            : ' after flutter run --machine exited '
                '(exitCode=$exitCode): $diagnostics';
    throw TimeoutException(
      'Remote session did not become ready at $baseUri$suffix.',
      deadline.difference(_now()),
    );
  }

  Object? _machineExitError({
    required CockpitLaunchDevelopmentMachineSessionRequest request,
    required CockpitFlutterRunMachineClient machineClient,
    required bool remoteSessionReady,
  }) {
    final exitCode = machineClient.lastExitCode;
    if (exitCode == null) {
      return null;
    }
    final diagnostics = machineClient.recentDiagnosticSummary;
    final suffix = diagnostics.isEmpty ? '' : ': $diagnostics';
    if (remoteSessionReady && _isPhysicalIosDevice(request)) {
      return CockpitDevelopmentSessionFallbackException(
        code: 'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
        message: 'The iOS physical-device remote session became reachable, but '
            'flutter run --machine exited before app.start '
            '(exitCode=$exitCode)$suffix. Automation fallback is safe.',
      );
    }
    return StateError(
      'Flutter run machine session exited before ${remoteSessionReady ? 'app.start' : 'the remote session became reachable'} '
      '(exitCode=$exitCode)$suffix',
    );
  }

  Future<CockpitRemoteSessionHandle>
      _buildPhysicalIosFallbackRemoteSessionHandle({
    required CockpitLaunchDevelopmentMachineSessionRequest request,
    required CockpitResolvedRemoteSessionEndpoint endpoint,
    required int hostPort,
    required CockpitRemoteSessionStatus status,
  }) async {
    final platformAppId = await _resolvePhysicalIosFallbackPlatformAppId(
      request: request,
    );
    final appId = platformAppId ?? status.sessionId;
    return CockpitRemoteSessionHandle.fromRemoteStatus(
      projectDir: request.projectDir,
      target: request.target,
      deviceId: request.deviceId,
      appId: appId,
      platformAppId: platformAppId,
      platformAppIdKnown: platformAppId != null,
      host: endpoint.publicHost,
      hostPort: hostPort,
      devicePort: request.sessionPort,
      status: status,
      launchedAt: _now(),
    );
  }

  Future<String?> _resolvePlatformAppId({
    required CockpitLaunchDevelopmentMachineSessionRequest request,
    required CockpitRemoteSessionStatus status,
  }) async {
    if (_isPhysicalIosDevice(request) &&
        status.platform.toLowerCase() == 'ios') {
      return _resolvePhysicalIosFallbackPlatformAppId(request: request);
    }
    try {
      return await _platformAppIdResolver(
        projectDir: request.projectDir,
        platform: request.platform,
        flavor: request.flavor,
      );
    } on Object {
      return null;
    }
  }

  Future<String?> _resolvePhysicalIosFallbackPlatformAppId({
    required CockpitLaunchDevelopmentMachineSessionRequest request,
  }) async {
    try {
      final appBundlePath = await _iosFallbackAppBundlePathResolver(
        projectDir: request.projectDir,
        flavor: request.flavor,
      );
      final bundleId = await _iosFallbackBundleIdResolver(
        appBundlePath: appBundlePath,
      );
      final normalized = bundleId.trim();
      return normalized.isEmpty ? null : normalized;
    } on Object {
      // Keep the ready remote session reusable even if bundle lookup fails.
      return null;
    }
  }

  bool _isPhysicalIosDevice(
    CockpitLaunchDevelopmentMachineSessionRequest request,
  ) {
    return request.platform == 'ios' &&
        !cockpitLooksLikeIosSimulatorDeviceId(request.deviceId);
  }
}

final class CockpitResolvedRemoteSessionEndpoint {
  const CockpitResolvedRemoteSessionEndpoint({
    required this.bindHost,
    required this.publicHost,
  });

  final String bindHost;
  final String publicHost;
}

Future<String> _resolveIosPhysicalAppBundlePath({
  required String projectDir,
  String? flavor,
}) async {
  final pathContext = cockpitSessionPathContext(projectDir);
  final buildDirectory = Directory(
    pathContext.join(projectDir, 'build', 'ios', 'iphoneos'),
  );
  if (!buildDirectory.existsSync()) {
    throw StateError(
      'Unable to locate iOS device build output at ${buildDirectory.path}.',
    );
  }
  return cockpitSelectBestAppBundlePath(
    searchRoot: buildDirectory,
    flavor: flavor,
    pathContext: pathContext,
    platformLabel: 'iOS device',
  );
}
