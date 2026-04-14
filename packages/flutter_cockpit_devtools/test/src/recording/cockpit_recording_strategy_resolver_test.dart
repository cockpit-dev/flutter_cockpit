import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  const autoRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'acceptance-demo',
    attachToStep: true,
  );
  const nativeRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'native-demo',
    mode: CockpitRecordingMode.native,
  );
  const fullRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'full-demo',
    mode: CockpitRecordingMode.full,
  );
  const strictFlutterLayerRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'flutter-layer-demo',
    layer: CockpitRecordingLayer.flutter,
  );
  const fallbackSystemLayerRequest = CockpitRecordingRequest(
    purpose: CockpitRecordingPurpose.acceptance,
    name: 'system-fallback-demo',
    layer: CockpitRecordingLayer.system,
    allowFallback: true,
  );

  test('prefers adb system recording for Android auto mode', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'android',
      recording: autoRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      androidDeviceId: 'emulator-5554',
    );

    expect(resolution?.implementation, 'adb');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.system);
    expect(resolution?.fallbackUsed, isFalse);
    expect(resolution?.adapter, isNotNull);
  });

  test(
    'uses simctl system recording for iOS auto mode when a simulator device ID is provided',
    () {
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'ios',
        recording: autoRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        iosDeviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      );

      expect(resolution?.implementation, 'simctl');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.system);
      expect(resolution?.fallbackUsed, isFalse);
    },
  );

  test(
    'uses remote native recording for iOS native mode even when a simulator device ID is provided',
    () {
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'ios',
        recording: nativeRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
        iosDeviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      );

      expect(resolution?.implementation, 'remote');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.system);
      expect(resolution?.fallbackUsed, isFalse);
    },
  );

  test('uses host-screen recording for macOS full mode', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'macos',
      recording: fullRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      platformAppId: 'dev.cockpit.cockpitDemo',
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

    expect(resolution?.implementation, 'macosHost');
    expect(resolution?.effectiveLayer, CockpitRecordingLayer.hostScreen);
    expect(resolution?.fallbackUsed, isFalse);
  });

  test(
    'falls back to app-window recording when macOS system-layer recording is requested with fallback enabled',
    () {
      final resolver = CockpitRecordingStrategyResolver(
        remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
        adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
        simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      );

      final resolution = resolver.resolveDetailed(
        platform: 'macos',
        recording: fallbackSystemLayerRequest,
        client: CockpitRemoteSessionClient(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
      );

      expect(resolution?.implementation, 'remote');
      expect(resolution?.effectiveLayer, CockpitRecordingLayer.appWindow);
      expect(resolution?.fallbackUsed, isTrue);
      expect(resolution?.fallbackReason, contains('system'));
    },
  );

  test('reports unsupported flutter-layer recording when fallback is disabled',
      () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'ios',
      recording: strictFlutterLayerRequest,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
    );

    expect(resolution?.adapter, isNull);
    expect(resolution?.unsupportedReason, contains('flutter'));
  });

  test('returns null when the script does not request recording', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      macosAdapterFactory: (appId) => _FakeRecordingAdapter(),
    );

    final resolution = resolver.resolveDetailed(
      platform: 'android',
      recording: null,
      client: CockpitRemoteSessionClient(
        baseUri: Uri.parse('http://127.0.0.1:47331'),
      ),
      androidDeviceId: 'emulator-5554',
    );

    expect(resolution, isNull);
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
