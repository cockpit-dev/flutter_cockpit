import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/application/cockpit_stop_development_session_service.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_reference_resolver.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_status.dart';
import 'package:test/test.dart';

void main() {
  test(
    'stop service resolves a persisted handle and returns a final stopped status',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_stop_development_session_service',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final handle = _handle();
      final handleFile = File('${tempDir.path}/development_handle.json');
      await handleFile.writeAsString(jsonEncode(handle.toJson()));

      final service = CockpitStopDevelopmentSessionService(
        sessionReferenceResolver:
            const CockpitDevelopmentSessionReferenceResolver(),
        stopper: (supervisorBaseUri) async {
          expect(supervisorBaseUri, handle.supervisorBaseUri);
          return CockpitDevelopmentSessionStopResult(
            sessionHandle: handle,
            status: CockpitDevelopmentSessionStatus(
              developmentSessionId: handle.developmentSessionId,
              state: CockpitDevelopmentSessionState.stopped,
              appReachable: false,
              remoteSessionReachable: false,
              reloadGeneration: handle.reloadGeneration,
              lastStatusAt: DateTime.utc(2026, 3, 23, 0, 6),
            ),
          );
        },
      );

      final result = await service.stop(
        CockpitStopDevelopmentSessionRequest(
          sessionHandlePath: handleFile.path,
        ),
      );

      expect(result.sessionHandle.toJson(), handle.toJson());
      expect(result.status.state, CockpitDevelopmentSessionState.stopped);
    },
  );

  test(
    'stop service treats an unreachable supervisor as an already stopped session',
    () async {
      final handle = _handle();
      final service = CockpitStopDevelopmentSessionService(
        stopper: (_) async => throw SocketException(
          'Connection refused',
          address: InternetAddress.loopbackIPv4,
          port: 59421,
        ),
      );

      final result = await service.stop(
        CockpitStopDevelopmentSessionRequest(sessionHandle: handle),
      );

      expect(result.sessionHandle.toJson(), handle.toJson());
      expect(result.status.state, CockpitDevelopmentSessionState.stopped);
      expect(result.status.appReachable, isFalse);
      expect(result.status.remoteSessionReachable, isFalse);
      expect(result.status.lastError, contains('Connection refused'));
    },
  );
}

CockpitDevelopmentSessionHandle _handle() {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-1',
    platform: 'ios',
    deviceId: 'simulator',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'lib/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:57331',
    supervisorBaseUrl: 'http://127.0.0.1:59421',
    launchedAt: DateTime.utc(2026, 3, 23, 0, 0),
    reloadGeneration: 1,
  );
}
