import 'dart:convert';
import 'dart:io';

import 'package:cockpit/src/application/cockpit_reload_development_session_service.dart';
import 'package:cockpit/src/development/cockpit_development_session_handle.dart';
import 'package:cockpit/src/development/cockpit_development_session_reference_resolver.dart';
import 'package:cockpit/src/development/cockpit_development_session_status.dart';
import 'package:test/test.dart';

void main() {
  test(
    'reload service resolves a persisted handle, increments generation, and rewrites the handle file',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_reload_development_session_service',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final handle = _handle();
      final handleFile = File('${tempDir.path}/development_handle.json');
      await handleFile.writeAsString(jsonEncode(handle.toJson()));

      final reloadedHandle = handle.copyWith(
        reloadGeneration: 2,
        lastReloadAt: DateTime.utc(2026, 3, 23, 0, 5),
      );
      final service = CockpitReloadDevelopmentSessionService(
        sessionReferenceResolver:
            const CockpitDevelopmentSessionReferenceResolver(),
        reloader: (supervisorBaseUri, mode) async {
          expect(supervisorBaseUri, handle.supervisorBaseUri);
          expect(mode, CockpitDevelopmentReloadMode.hotReload);
          return CockpitDevelopmentSessionReloadResult(
            sessionHandle: reloadedHandle,
            status: CockpitDevelopmentSessionStatus(
              developmentSessionId: reloadedHandle.developmentSessionId,
              state: CockpitDevelopmentSessionState.ready,
              appReachable: true,
              remoteSessionReachable: true,
              reloadGeneration: 2,
              lastReloadMode: CockpitDevelopmentReloadMode.hotReload,
              lastReloadSucceeded: true,
              lastStatusAt: DateTime.utc(2026, 3, 23, 0, 5),
            ),
          );
        },
      );

      final result = await service.reload(
        CockpitReloadDevelopmentSessionRequest(
          sessionHandlePath: handleFile.path,
          mode: CockpitDevelopmentReloadMode.hotReload,
        ),
      );

      expect(result.sessionHandle.reloadGeneration, 2);
      expect(
        result.status.lastReloadMode,
        CockpitDevelopmentReloadMode.hotReload,
      );
      final persistedJson =
          jsonDecode(await handleFile.readAsString()) as Map<String, Object?>;
      expect(persistedJson['reloadGeneration'], 2);
    },
  );
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
  );
}
