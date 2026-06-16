import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/capture/cockpit_host_preferred_capture_adapter.dart';
import 'package:test/test.dart';

void main() {
  test('uses adb host capture when an Android device ID is provided', () {
    final remoteAdapter = _FakeCaptureAdapter();
    final adbAdapter = _FakeCaptureAdapter();
    final resolver = CockpitCaptureStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => adbAdapter,
      simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
    );

    final adapter = resolver.resolve(
      platform: 'android',
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      androidDeviceId: 'emulator-5554',
    );

    expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
  });

  test(
    'uses simctl host capture when an iOS simulator device ID is provided',
    () {
      final remoteAdapter = _FakeCaptureAdapter();
      final simctlAdapter = _FakeCaptureAdapter();
      final resolver = CockpitCaptureStrategyResolver(
        remoteAdapterFactory: (client) => remoteAdapter,
        adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
        simctlAdapterFactory: (deviceId) => simctlAdapter,
      );

      final adapter = resolver.resolve(
        platform: 'ios',
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        iosDeviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      );

      expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
    },
  );

  test('uses remote capture for physical iOS device IDs', () {
    final remoteAdapter = _FakeCaptureAdapter();
    final resolver = CockpitCaptureStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
    );

    final adapter = resolver.resolve(
      platform: 'ios',
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      iosDeviceId: '00008110-0009341C2EF3801E',
    );

    expect(adapter, same(remoteAdapter));
  });

  test('uses host-preferred capture on macos when an app id is available', () {
    final remoteAdapter = _FakeCaptureAdapter();
    final macosAdapter = _FakeCaptureAdapter();
    final resolver = CockpitCaptureStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      macosAdapterFactory: (appId) => macosAdapter,
    );

    final adapter = resolver.resolve(
      platform: 'macos',
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      sessionHandle: CockpitRemoteSessionHandle(
        platform: 'macos',
        deviceId: 'macos',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 3, 24),
      ),
    );

    expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
  });

  test(
    'uses host-preferred capture on windows when an app id is available',
    () {
      final remoteAdapter = _FakeCaptureAdapter();
      final windowsAdapter = _FakeCaptureAdapter();
      String? capturedAppId;
      int? capturedProcessId;
      final resolver = CockpitCaptureStrategyResolver(
        remoteAdapterFactory: (client) => remoteAdapter,
        adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
        macosAdapterFactory: (appId) => _FakeCaptureAdapter(),
        windowsAdapterFactory: (appId, {processId}) {
          capturedAppId = appId;
          capturedProcessId = processId;
          return windowsAdapter;
        },
      );

      final adapter = resolver.resolve(
        platform: 'windows',
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'windows',
          deviceId: 'windows',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'cockpit_demo',
          processId: 4101,
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24),
        ),
      );

      expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
      expect(capturedAppId, 'cockpit_demo');
      expect(capturedProcessId, 4101);
    },
  );

  test(
    'uses host-preferred capture on windows when only a process id is available',
    () {
      final remoteAdapter = _FakeCaptureAdapter();
      final windowsAdapter = _FakeCaptureAdapter();
      String? capturedAppId;
      int? capturedProcessId;
      final resolver = CockpitCaptureStrategyResolver(
        remoteAdapterFactory: (client) => remoteAdapter,
        adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
        windowsAdapterFactory: (appId, {processId}) {
          capturedAppId = appId;
          capturedProcessId = processId;
          return windowsAdapter;
        },
      );

      final adapter = resolver.resolve(
        platform: 'windows',
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'windows',
          deviceId: 'windows',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'app-with-unknown-platform-id',
          platformAppIdKnown: false,
          processId: 4101,
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24),
        ),
      );

      expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
      expect(capturedAppId, 'pid-4101');
      expect(capturedProcessId, 4101);
    },
  );

  test('uses host-preferred capture on linux when an app id is available', () {
    final remoteAdapter = _FakeCaptureAdapter();
    final linuxAdapter = _FakeCaptureAdapter();
    String? capturedAppId;
    int? capturedProcessId;
    final resolver = CockpitCaptureStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      macosAdapterFactory: (appId) => _FakeCaptureAdapter(),
      linuxAdapterFactory: (appId, {processId}) {
        capturedAppId = appId;
        capturedProcessId = processId;
        return linuxAdapter;
      },
    );

    final adapter = resolver.resolve(
      platform: 'linux',
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      sessionHandle: CockpitRemoteSessionHandle(
        platform: 'linux',
        deviceId: 'linux',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'cockpit_demo',
        processId: 5101,
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 3, 24),
      ),
    );

    expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
    expect(capturedAppId, 'cockpit_demo');
    expect(capturedProcessId, 5101);
  });

  test(
    'uses host-preferred capture on linux when only a process id is available',
    () {
      final remoteAdapter = _FakeCaptureAdapter();
      final linuxAdapter = _FakeCaptureAdapter();
      String? capturedAppId;
      int? capturedProcessId;
      final resolver = CockpitCaptureStrategyResolver(
        remoteAdapterFactory: (client) => remoteAdapter,
        adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
        linuxAdapterFactory: (appId, {processId}) {
          capturedAppId = appId;
          capturedProcessId = processId;
          return linuxAdapter;
        },
      );

      final adapter = resolver.resolve(
        platform: 'linux',
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        sessionHandle: CockpitRemoteSessionHandle(
          platform: 'linux',
          deviceId: 'linux',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          appId: 'app-with-unknown-platform-id',
          platformAppIdKnown: false,
          processId: 5101,
          host: '127.0.0.1',
          hostPort: 47331,
          devicePort: 47331,
          baseUrl: 'http://127.0.0.1:47331',
          launchedAt: DateTime.utc(2026, 3, 24),
        ),
      );

      expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
      expect(capturedAppId, 'pid-5101');
      expect(capturedProcessId, 5101);
    },
  );

  test('falls back to remote capture when no host context is available', () {
    final remoteAdapter = _FakeCaptureAdapter();
    final resolver = CockpitCaptureStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      macosAdapterFactory: (appId) => _FakeCaptureAdapter(),
    );

    final adapter = resolver.resolve(
      platform: 'macos',
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
    );

    expect(adapter, same(remoteAdapter));
  });
}

final class _FakeCaptureAdapter implements CockpitCaptureAdapter {
  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) {
    throw UnimplementedError();
  }
}
