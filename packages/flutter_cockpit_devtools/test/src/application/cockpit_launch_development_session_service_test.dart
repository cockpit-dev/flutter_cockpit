import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_development_session_service.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_status.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_supervisor_client.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_android_port_forwarder.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'launch service returns a reusable development handle, ready status, and optional persisted json',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_launch_development_session_service',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final expectedHandle = _handle();
      final expectedStatus = _readyStatus(expectedHandle);
      final outputFile = File(
        p.join(tempDir.path, 'development_session_handle.json'),
      );

      final service = CockpitLaunchDevelopmentSessionService(
        launcher: (request) async {
          expect(request.projectDir, expectedHandle.projectDir);
          expect(request.target, expectedHandle.target);
          expect(request.platform, expectedHandle.platform);
          expect(request.deviceId, expectedHandle.deviceId);
          expect(request.sessionPort, 47331);
          return CockpitDevelopmentSessionBootstrap(
            sessionHandle: expectedHandle,
            status: expectedStatus,
          );
        },
      );

      final result = await service.launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: expectedHandle.projectDir,
          target: expectedHandle.target,
          platform: expectedHandle.platform,
          deviceId: expectedHandle.deviceId,
          sessionPort: 47331,
          persistHandlePath: outputFile.path,
        ),
      );

      expect(result.sessionHandle.toJson(), expectedHandle.toJson());
      expect(result.status.toJson(), expectedStatus.toJson());
      expect(result.persistedHandlePath, outputFile.path);

      final persistedJson =
          jsonDecode(await outputFile.readAsString()) as Map<String, Object?>;
      expect(persistedJson['developmentSessionId'], 'dev-session-1');
      expect(persistedJson['reloadGeneration'], 1);
      expect(persistedJson['supervisorBaseUrl'], 'http://127.0.0.1:59421');
    },
  );

  test(
    'daemon launcher retries by stopping only the failed spawned attempt',
    () async {
      final statusesByBaseUri =
          <Uri, List<CockpitDevelopmentSessionBootstrap?>>{};
      final stopCalls = <Uri>[];
      final spawnCalls = <Uri>[];
      final readyHandle = _handle();
      final readyStatus = _readyStatus(readyHandle);

      final firstBaseUri = Uri.parse('http://127.0.0.1:60001');
      final secondBaseUri = Uri.parse('http://127.0.0.1:60002');
      statusesByBaseUri[firstBaseUri] = <CockpitDevelopmentSessionBootstrap?>[
        null,
        CockpitDevelopmentSessionBootstrap(
          sessionHandle: readyHandle.copyWith(
            supervisorBaseUrl: firstBaseUri.toString(),
          ),
          status: readyStatus.copyWith(
            state: CockpitDevelopmentSessionState.failed,
            lastError: 'startup lock held by another cockpit attempt',
          ),
        ),
      ];
      statusesByBaseUri[secondBaseUri] = <CockpitDevelopmentSessionBootstrap?>[
        CockpitDevelopmentSessionBootstrap(
          sessionHandle: readyHandle.copyWith(
            supervisorBaseUrl: secondBaseUri.toString(),
          ),
          status: readyStatus.copyWith(
            developmentSessionId: readyHandle.developmentSessionId,
          ),
        ),
      ];

      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (baseUri) async {
          final queue = statusesByBaseUri[baseUri]!;
          final next = queue.removeAt(0);
          if (next == null) {
            throw StateError('connection refused');
          }
          return CockpitDevelopmentSessionSupervisorResponse(
            sessionHandle: next.sessionHandle,
            status: next.status,
          );
        },
        portForwarder: const _StubPortForwarder(57331),
        flutterVersionReader: () async => '3.39.0',
        allocatePort: () async => spawnCalls.isEmpty ? 60001 : 60002,
        delay: (_) async {},
        spawnSupervisor: ({
          required request,
          required flutterVersion,
          required hostPort,
          required supervisorPort,
          required supervisorLogFile,
        }) async {
          final baseUri = Uri.parse('http://127.0.0.1:$supervisorPort');
          spawnCalls.add(baseUri);
          return CockpitSpawnedDevelopmentSupervisor(
            baseUri: baseUri,
            stop: () async {
              stopCalls.add(baseUri);
            },
          );
        },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'android',
          deviceId: 'emulator-5554',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 5),
        ),
      );

      expect(spawnCalls, orderedEquals(<Uri>[firstBaseUri, secondBaseUri]));
      expect(stopCalls, orderedEquals(<Uri>[firstBaseUri]));
      expect(result.sessionHandle.supervisorBaseUri, secondBaseUri);
      expect(result.status.state, CockpitDevelopmentSessionState.ready);
    },
  );

  test(
    'daemon launcher uses direct host port for macos without Android forwarding',
    () async {
      final readyHandle = CockpitDevelopmentSessionHandle(
        developmentSessionId: 'dev-session-macos',
        platform: 'macos',
        deviceId: 'macos',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        appBaseUrl: 'http://127.0.0.1:47331',
        supervisorBaseUrl: 'http://127.0.0.1:60003',
        launchedAt: DateTime.utc(2026, 3, 24, 0, 0),
        reloadGeneration: 0,
        remoteSessionHandle: CockpitRemoteSessionHandle(
          platform: 'macos',
          deviceId: 'macos',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'dev.cockpit.cockpitDemo',
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24, 0, 0),
        ),
      );
      final readyStatus = CockpitDevelopmentSessionStatus(
        developmentSessionId: readyHandle.developmentSessionId,
        state: CockpitDevelopmentSessionState.ready,
        appReachable: true,
        remoteSessionReachable: true,
        reloadGeneration: readyHandle.reloadGeneration,
        lastStatusAt: DateTime.utc(2026, 3, 24, 0, 1),
      );

      var capturedHostPort = -1;
      var capturedPlatform = '';
      final launcher = CockpitDevelopmentSessionDaemonLauncher(
        supervisorStatusReader: (baseUri) async =>
            CockpitDevelopmentSessionSupervisorResponse(
          sessionHandle: readyHandle,
          status: readyStatus,
        ),
        portForwarder: const _ThrowingPortForwarder(),
        flutterVersionReader: () async => '3.39.0',
        allocatePort: () async => 60003,
        delay: (_) async {},
        spawnSupervisor: ({
          required request,
          required flutterVersion,
          required hostPort,
          required supervisorPort,
          required supervisorLogFile,
        }) async {
          capturedHostPort = hostPort;
          capturedPlatform = request.platform;
          return CockpitSpawnedDevelopmentSupervisor(
            baseUri: Uri.parse('http://127.0.0.1:$supervisorPort'),
            stop: () async {},
          );
        },
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
          launchTimeout: Duration(seconds: 5),
        ),
      );

      expect(capturedPlatform, 'macos');
      expect(capturedHostPort, 47331);
      expect(result.sessionHandle.platform, 'macos');
      expect(result.status.state, CockpitDevelopmentSessionState.ready);
    },
  );
}

final class _StubPortForwarder extends CockpitAndroidPortForwarder {
  const _StubPortForwarder(this.hostPort);

  final int hostPort;

  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) async {
    return hostPort;
  }
}

final class _ThrowingPortForwarder extends CockpitAndroidPortForwarder {
  const _ThrowingPortForwarder();

  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) async {
    throw StateError('macos bootstrap must not request Android forwarding');
  }
}

CockpitDevelopmentSessionHandle _handle() {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-1',
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'lib/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:57331',
    supervisorBaseUrl: 'http://127.0.0.1:59421',
    launchedAt: DateTime.utc(2026, 3, 23, 0, 0),
    reloadGeneration: 1,
    remoteSessionHandle: CockpitRemoteSessionHandle(
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'lib/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 57331,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:57331',
      launchedAt: DateTime.utc(2026, 3, 23, 0, 0),
    ),
  );
}

CockpitDevelopmentSessionStatus _readyStatus(
  CockpitDevelopmentSessionHandle handle,
) {
  return CockpitDevelopmentSessionStatus(
    developmentSessionId: handle.developmentSessionId,
    state: CockpitDevelopmentSessionState.ready,
    appReachable: true,
    remoteSessionReachable: true,
    reloadGeneration: handle.reloadGeneration,
    lastStatusAt: DateTime.utc(2026, 3, 23, 0, 1),
  );
}
