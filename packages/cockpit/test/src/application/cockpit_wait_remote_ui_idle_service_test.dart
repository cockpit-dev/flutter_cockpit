import 'package:cockpit/src/application/cockpit_wait_remote_ui_idle_service.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitWaitRemoteUiIdleService', () {
    test('waits for UI idle through a resolved session handle', () async {
      Uri? capturedBaseUri;
      Duration? capturedQuietWindow;
      Duration? capturedTimeout;
      bool? capturedIncludeNetworkIdle;
      final service = CockpitWaitRemoteUiIdleService(
        waitForIdle:
            (
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

    test('retries one transient false idle result before failing', () async {
      var attemptCount = 0;
      final waitedDurations = <Duration>[];
      final service = CockpitWaitRemoteUiIdleService(
        waitForIdle:
            (
              baseUri, {
              required quietWindow,
              required timeout,
              required includeNetworkIdle,
            }) async {
              attemptCount += 1;
              return attemptCount > 1;
            },
        wait: (duration) async {
          waitedDurations.add(duration);
        },
      );

      final result = await service.wait(
        CockpitWaitRemoteUiIdleRequest(
          sessionHandle: _sessionHandle(),
          quietWindow: const Duration(milliseconds: 96),
          timeout: const Duration(milliseconds: 1600),
        ),
      );

      expect(result.idle, isTrue);
      expect(attemptCount, 2);
      expect(waitedDurations, const <Duration>[Duration(milliseconds: 120)]);
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
