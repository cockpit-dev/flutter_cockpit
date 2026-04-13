import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitStartRecordingService', () {
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
  });
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
