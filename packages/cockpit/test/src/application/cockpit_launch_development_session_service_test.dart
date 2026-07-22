import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/application/cockpit_entrypoint_resolver.dart';
import 'package:cockpit/src/application/cockpit_launch_development_session_service.dart';
import 'package:cockpit/src/development/cockpit_development_session_handle.dart';
import 'package:cockpit/src/development/cockpit_development_session_status.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('normalizes launch input and persists requested handles', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit-development-launch-service-',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final handle = _handle();
    final status = _readyStatus(handle);
    final handleFile = File(p.join(tempDir.path, 'session.json'));
    final appFile = File(p.join(tempDir.path, 'app.json'));
    CockpitLaunchDevelopmentSessionRequest? captured;
    final service = CockpitLaunchDevelopmentSessionService(
      entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
      launcher: (request) async {
        captured = request;
        return CockpitDevelopmentSessionBootstrap(
          sessionHandle: handle,
          status: status,
        );
      },
    );

    final result = await service.launch(
      CockpitLaunchDevelopmentSessionRequest(
        projectDir: '${handle.projectDir}/.',
        target: handle.target,
        platform: handle.platform,
        deviceId: handle.deviceId,
        sessionPort: 47331,
        persistHandlePath: handleFile.path,
        persistAppHandlePath: appFile.path,
      ),
    );

    expect(captured?.projectDir, cockpitNormalizeProjectDir(handle.projectDir));
    expect(captured?.target, p.normalize(handle.target));
    expect(result.sessionHandle, same(handle));
    expect(result.status, same(status));
    expect(result.persistedHandlePath, handleFile.path);
    expect(result.appJsonPath, appFile.path);
    expect(
      (jsonDecode(await handleFile.readAsString())
          as Map)['developmentSessionId'],
      handle.developmentSessionId,
    );
    expect(
      (jsonDecode(await appFile.readAsString()) as Map)['mode'],
      'development',
    );
  });

  test('infers cockpit/main.dart when target is omitted', () async {
    final handle = _handle(target: 'cockpit/main.dart');
    final expectedPath = p.join(
      cockpitNormalizeProjectDir(handle.projectDir),
      'cockpit',
      'main.dart',
    );
    final service = CockpitLaunchDevelopmentSessionService(
      entrypointResolver: CockpitEntrypointResolver(
        exists: (path) => p.equals(path, expectedPath),
      ),
      launcher: (request) async {
        expect(request.target, 'cockpit/main.dart');
        return CockpitDevelopmentSessionBootstrap(
          sessionHandle: handle,
          status: _readyStatus(handle),
        );
      },
    );

    final result = await service.launch(
      CockpitLaunchDevelopmentSessionRequest(
        projectDir: handle.projectDir,
        platform: handle.platform,
        deviceId: handle.deviceId,
        sessionPort: 47331,
      ),
    );

    expect(result.sessionHandle.target, 'cockpit/main.dart');
  });

  test(
    'remaps an occupied local session port when fallback is allowed',
    () async {
      CockpitLaunchDevelopmentSessionRequest? captured;
      final handle = _handle();
      final service = CockpitLaunchDevelopmentSessionService(
        entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
        sessionPortAvailabilityChecker: (_) async => false,
        sessionPortAllocator: () async => 59331,
        launcher: (request) async {
          captured = request;
          return CockpitDevelopmentSessionBootstrap(
            sessionHandle: handle,
            status: _readyStatus(handle),
          );
        },
      );

      await service.launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: handle.projectDir,
          target: handle.target,
          platform: 'ios',
          deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
          sessionPort: 57331,
        ),
      );

      expect(captured?.sessionPort, 59331);
    },
  );

  test('unrouted production construction rejects direct launch', () async {
    final handle = _handle();
    final service = CockpitLaunchDevelopmentSessionService(
      entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
    );

    await expectLater(
      service.launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: handle.projectDir,
          target: handle.target,
          platform: handle.platform,
          deviceId: handle.deviceId,
          sessionPort: 47331,
          allowSessionPortFallback: false,
        ),
      ),
      throwsA(
        isA<UnsupportedError>().having(
          (error) => error.message,
          'message',
          contains('workspace worker'),
        ),
      ),
    );
  });
}

CockpitDevelopmentSessionHandle _handle({String target = 'lib/main.dart'}) =>
    CockpitDevelopmentSessionHandle(
      developmentSessionId: 'development_session_1',
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/examples/cockpit_demo',
      target: target,
      appId: 'dev.cockpit.demo',
      appBaseUrl: 'http://127.0.0.1:47331',
      supervisorBaseUrl: 'cockpit-worker://development/development_session_1',
      launchedAt: DateTime.utc(2026, 7, 22),
      reloadGeneration: 0,
      remoteSessionHandle: CockpitRemoteSessionHandle(
        platform: 'android',
        deviceId: 'emulator-5554',
        projectDir: '/workspace/examples/cockpit_demo',
        target: target,
        appId: 'dev.cockpit.demo',
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 7, 22),
      ),
    );

CockpitDevelopmentSessionStatus _readyStatus(
  CockpitDevelopmentSessionHandle handle,
) => CockpitDevelopmentSessionStatus(
  developmentSessionId: handle.developmentSessionId,
  state: CockpitDevelopmentSessionState.ready,
  appReachable: true,
  remoteSessionReachable: true,
  reloadGeneration: handle.reloadGeneration,
  lastStatusAt: DateTime.utc(2026, 7, 22),
);
