import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/capture/cockpit_host_preferred_capture_adapter.dart';
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

  test('uses simctl host capture when an iOS device ID is provided', () {
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

  test('uses host-preferred capture on windows when an app id is available',
      () {
    final remoteAdapter = _FakeCaptureAdapter();
    final windowsAdapter = _FakeCaptureAdapter();
    final resolver = CockpitCaptureStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      macosAdapterFactory: (appId) => _FakeCaptureAdapter(),
      windowsAdapterFactory: (appId) => windowsAdapter,
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
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 3, 24),
      ),
    );

    expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
  });

  test('uses host-preferred capture on linux when an app id is available', () {
    final remoteAdapter = _FakeCaptureAdapter();
    final linuxAdapter = _FakeCaptureAdapter();
    final resolver = CockpitCaptureStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeCaptureAdapter(),
      macosAdapterFactory: (appId) => _FakeCaptureAdapter(),
      linuxAdapterFactory: (appId) => linuxAdapter,
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
        host: '127.0.0.1',
        hostPort: 47331,
        devicePort: 47331,
        baseUrl: 'http://127.0.0.1:47331',
        launchedAt: DateTime.utc(2026, 3, 24),
      ),
    );

    expect(adapter, isA<CockpitHostPreferredCaptureAdapter>());
  });

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
