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

  test('returns null when the script does not request recording', () {
    final resolver = CockpitRecordingStrategyResolver(
      remoteAdapterFactory: (client) => _FakeRecordingAdapter(),
      adbAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
      simctlAdapterFactory: (deviceId) => _FakeRecordingAdapter(),
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
