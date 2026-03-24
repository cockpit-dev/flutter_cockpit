import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  const request = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'acceptance-demo',
    attachToStep: true,
  );

  test('uses adb host recording when an Android device ID is provided', () {
    final remoteAdapter = _FakeRecordingAdapter();
    final adbAdapter = _FakeRecordingAdapter();
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => adbAdapter,
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
    );

    final adapter = resolver.resolve(
      platform: 'android',
      recording: request,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      androidDeviceId: 'emulator-5554',
    );

    expect(adapter, same(adbAdapter));
  });

  test(
    'uses simctl host recording on iOS when a simulator device ID is provided',
    () {
      final remoteAdapter = _FakeRecordingAdapter();
      final simctlAdapter = _FakeRecordingAdapter();
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => remoteAdapter,
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => simctlAdapter,
      );

      final adapter = resolver.resolve(
        platform: 'ios',
        recording: request,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        iosDeviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      );

      expect(adapter, same(simctlAdapter));
    },
  );

  test(
    'falls back to remote recording when no host device handle is available',
    () {
      final remoteAdapter = _FakeRecordingAdapter();
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => remoteAdapter,
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final adapter = resolver.resolve(
        platform: 'ios',
        recording: request,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
      );

      expect(adapter, same(remoteAdapter));
    },
  );

  test('uses remote recording on macos when a session handle is provided', () {
    final remoteAdapter = _FakeRecordingAdapter();
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
    );

    final adapter = resolver.resolve(
      platform: 'macos',
      recording: request,
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

    expect(adapter, same(remoteAdapter));
  });

  test('uses remote recording on windows when a session handle is provided',
      () {
    final remoteAdapter = _FakeRecordingAdapter();
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
      windowsAdapterFactory: (appId) => _FakeRecordingAdapter(),
    );

    final adapter = resolver.resolve(
      platform: 'windows',
      recording: request,
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

    expect(adapter, same(remoteAdapter));
  });

  test('uses linux host recording when a linux session handle is provided', () {
    final remoteAdapter = _FakeRecordingAdapter();
    final linuxAdapter = _FakeRecordingAdapter();
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => remoteAdapter,
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
      linuxAdapterFactory: (appId) => linuxAdapter,
    );

    final adapter = resolver.resolve(
      platform: 'linux',
      recording: request,
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

    expect(adapter, same(linuxAdapter));
  });

  test('returns null when the script does not request recording', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
    );

    final adapter = resolver.resolve(
      platform: 'android',
      recording: null,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      androidDeviceId: 'emulator-5554',
    );

    expect(adapter, isNull);
  });
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<CockpitRecordingResult> stopRecording() {
    throw UnimplementedError();
  }
}
