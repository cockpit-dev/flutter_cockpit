import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitStartRecordingService', () {
    test(
      'uses adb host recording for Android apps when auto mode has a device handle',
      () async {
        var remoteStartCalled = false;
        final hostAdapter = _FakeRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
        );
        final service = CockpitStartRecordingService(
          startService: CockpitStartRemoteRecordingService(
            startRecording: (_, __) async {
              remoteStartCalled = true;
              throw StateError(
                'remote start should not be used for Android host recording',
              );
            },
          ),
          recordingStrategyResolver: CockpitRecordingStrategyResolver(
            remoteAdapterFactory: (_) => _FakeRecordingAdapter(),
            adbAdapterFactory: (_) => hostAdapter,
            simctlAdapterFactory: (_) => _FakeRecordingAdapter(),
          ),
        );

        final result = await service.start(
          CockpitStartRecordingRequest(
            app: _androidAppHandle(),
            recording: const CockpitRecordingRequest(
              purpose: CockpitRecordingPurpose.acceptance,
              name: 'android-host-recording',
            ),
          ),
        );

        expect(remoteStartCalled, isFalse);
        expect(result.recordingSession.state, CockpitRecordingState.recording);
        expect(
            hostAdapter.startedRequests.single.name, 'android-host-recording');
      },
    );

    test(
      'uses simctl host recording for iOS apps instead of remote runtime recording',
      () async {
        var remoteStartCalled = false;
        final hostAdapter = _FakeRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
        );
        final service = CockpitStartRecordingService(
          startService: CockpitStartRemoteRecordingService(
            startRecording: (_, __) async {
              remoteStartCalled = true;
              throw StateError(
                'remote start should not be used for iOS host recording',
              );
            },
          ),
          recordingStrategyResolver: CockpitRecordingStrategyResolver(
            remoteAdapterFactory: (_) => _FakeRecordingAdapter(),
            adbAdapterFactory: (_) => _FakeRecordingAdapter(),
            simctlAdapterFactory: (_) => hostAdapter,
          ),
        );

        final result = await service.start(
          CockpitStartRecordingRequest(
            app: _iosAppHandle(),
            recording: const CockpitRecordingRequest(
              purpose: CockpitRecordingPurpose.acceptance,
              name: 'ios-host-recording',
            ),
          ),
        );

        expect(remoteStartCalled, isFalse);
        expect(result.recordingSession.state, CockpitRecordingState.recording);
        expect(hostAdapter.startedRequests.single.name, 'ios-host-recording');
      },
    );

    test(
      'uses remote native recording for iOS native mode',
      () async {
        var remoteStartCalled = false;
        final nativeAdapter = _FakeRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
        );
        final simctlAdapter = _FakeRecordingAdapter(
          onStart: (_) async => throw StateError(
            'simctl should not be used for native mode',
          ),
        );
        final service = CockpitStartRecordingService(
          startService: CockpitStartRemoteRecordingService(
            startRecording: (_, __) async {
              remoteStartCalled = true;
              throw StateError(
                'remote start service should not be used when resolver selects a native adapter',
              );
            },
          ),
          recordingStrategyResolver: CockpitRecordingStrategyResolver(
            remoteAdapterFactory: (_) => nativeAdapter,
            adbAdapterFactory: (_) => _FakeRecordingAdapter(),
            simctlAdapterFactory: (_) => simctlAdapter,
          ),
        );

        final result = await service.start(
          CockpitStartRecordingRequest(
            app: _iosAppHandle(),
            recording: const CockpitRecordingRequest(
              purpose: CockpitRecordingPurpose.acceptance,
              name: 'ios-native-recording',
              mode: CockpitRecordingMode.native,
            ),
          ),
        );

        expect(remoteStartCalled, isFalse);
        expect(result.recordingSession.state, CockpitRecordingState.recording);
        expect(
          nativeAdapter.startedRequests.single.mode,
          CockpitRecordingMode.native,
        );
      },
    );

    test(
      'uses macOS host recording with the resolved platform app id for full mode',
      () async {
        var remoteStartCalled = false;
        String? capturedAppId;
        final hostAdapter = _FakeRecordingAdapter(
          onStart: (request) async => CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
        );
        final service = CockpitStartRecordingService(
          startService: CockpitStartRemoteRecordingService(
            startRecording: (_, __) async {
              remoteStartCalled = true;
              throw StateError(
                'remote start should not be used for macOS full host recording',
              );
            },
          ),
          recordingStrategyResolver: CockpitRecordingStrategyResolver(
            remoteAdapterFactory: (_) => _FakeRecordingAdapter(),
            adbAdapterFactory: (_) => _FakeRecordingAdapter(),
            simctlAdapterFactory: (_) => _FakeRecordingAdapter(),
            macosAdapterFactory: (appId) {
              capturedAppId = appId;
              return hostAdapter;
            },
          ),
        );

        final result = await service.start(
          CockpitStartRecordingRequest(
            app: _macosAppHandle(),
            recording: const CockpitRecordingRequest(
              purpose: CockpitRecordingPurpose.acceptance,
              name: 'macos-host-recording',
              mode: CockpitRecordingMode.full,
            ),
          ),
        );

        expect(remoteStartCalled, isFalse);
        expect(capturedAppId, 'dev.cockpit.cockpitDemo.host');
        expect(result.recordingSession.state, CockpitRecordingState.recording);
        expect(hostAdapter.startedRequests.single.name, 'macos-host-recording');
      },
    );
  });
}

CockpitAppHandle _androidAppHandle() {
  return CockpitAppHandle(
    appId: 'android-app',
    mode: CockpitAppMode.development,
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    baseUrl: 'http://127.0.0.1:47331',
    launchedAt: DateTime.utc(2026, 4, 13),
  );
}

CockpitAppHandle _iosAppHandle() {
  return CockpitAppHandle(
    appId: 'ios-app',
    mode: CockpitAppMode.development,
    platform: 'ios',
    deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    baseUrl: 'http://127.0.0.1:47331',
    launchedAt: DateTime.utc(2026, 4, 13),
  );
}

CockpitAppHandle _macosAppHandle() {
  return CockpitAppHandle(
    appId: 'macos-app',
    platformAppId: 'dev.cockpit.cockpitDemo.host',
    mode: CockpitAppMode.automation,
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    baseUrl: 'http://127.0.0.1:47331',
    remoteSession: CockpitRemoteSessionHandle(
      platform: 'macos',
      deviceId: 'macos',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      appId: 'dev.cockpit.cockpitDemo.session',
      host: '127.0.0.1',
      hostPort: 47331,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:47331',
      launchedAt: DateTime.utc(2026, 4, 13),
    ),
    launchedAt: DateTime.utc(2026, 4, 13),
  );
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  _FakeRecordingAdapter({
    this.onStart,
  });

  final Future<CockpitRecordingSession> Function(
      CockpitRecordingRequest request)? onStart;
  final Future<CockpitRecordingResult> Function()? onStop = null;
  final List<CockpitRecordingRequest> startedRequests =
      <CockpitRecordingRequest>[];

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    startedRequests.add(request);
    final onStart = this.onStart;
    if (onStart != null) {
      return onStart(request);
    }
    throw UnimplementedError();
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    final onStop = this.onStop;
    if (onStop != null) {
      return onStop();
    }
    throw UnimplementedError();
  }
}
