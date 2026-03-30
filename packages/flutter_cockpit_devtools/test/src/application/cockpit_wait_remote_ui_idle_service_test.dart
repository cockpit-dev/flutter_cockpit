import 'package:flutter_cockpit_devtools/src/application/cockpit_wait_remote_ui_idle_service.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitWaitRemoteUiIdleService', () {
    test('waits for UI idle through a resolved session handle', () async {
      Uri? capturedBaseUri;
      Duration? capturedQuietWindow;
      Duration? capturedTimeout;
      bool? capturedIncludeNetworkIdle;
      final service = CockpitWaitRemoteUiIdleService(
        waitForIdle: (
          baseUri, {
          required quietWindow,
          required timeout,
          required includeNetworkIdle,
        }) async {
          capturedBaseUri = baseUri;
          capturedQuietWindow = quietWindow;
          capturedTimeout = timeout;
          capturedIncludeNetworkIdle = includeNetworkIdle;
          return true;
        },
      );

      final result = await service.wait(
        CockpitWaitRemoteUiIdleRequest(
          sessionHandle: _sessionHandle(),
          quietWindow: const Duration(milliseconds: 150),
          timeout: const Duration(seconds: 2),
          includeNetworkIdle: false,
        ),
      );

      expect(capturedBaseUri, _sessionHandle().baseUri);
      expect(capturedQuietWindow, const Duration(milliseconds: 150));
      expect(capturedTimeout, const Duration(seconds: 2));
      expect(capturedIncludeNetworkIdle, isFalse);
      expect(result.idle, isTrue);
      expect(result.durationMs, greaterThanOrEqualTo(0));
    });
  });
}

CockpitRemoteSessionHandle _sessionHandle() {
  return CockpitRemoteSessionHandle(
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    appId: 'dev.cockpit.demo',
    host: '127.0.0.1',
    hostPort: 47331,
    devicePort: 47331,
    baseUrl: 'http://127.0.0.1:47331',
    launchedAt: DateTime.utc(2026, 3, 30),
  );
}
