import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitStopRecordingService', () {
    test(
      'uses remote runtime recording for iOS apps when no host recording session is active',
      () async {
        final nativeAdapter = _FakeRecordingAdapter(
          onStop: () async => CockpitRecordingResult(
            state: CockpitRecordingState.completed,
            purpose: CockpitRecordingPurpose.acceptance,
            recordingKind: CockpitRecordingKind.nativeScreen,
            effectiveLayer: CockpitRecordingLayer.system,
            artifact: const CockpitArtifactRef(
              role: 'recording',
              relativePath: 'recordings/ios-native-recording.mp4',
            ),
            durationMs: 2400,
            sourceFilePath: '/tmp/ios-native-recording.mp4',
          ),
        );
        final service = CockpitStopRecordingService(
          stopService: CockpitStopRemoteRecordingService(
            stopRecording: (_) async {
              throw StateError(
                'stop service should not be used when resolver selects an adapter',
              );
            },
          ),
          recordingStrategyResolver: CockpitRecordingStrategyResolver(
            remoteAdapterFactory: (_) => nativeAdapter,
            adbAdapterFactory: (_) => _FakeRecordingAdapter(),
            simctlAdapterFactory: (_) => _FakeRecordingAdapter(
              onStop: () async => throw StateError(
                'simctl should not be used without an active host session',
              ),
            ),
          ),
        );

        final result = await service.stop(
          CockpitStopRecordingRequest(
            app: _iosAppHandle(),
          ),
        );

        expect(result.state, CockpitRecordingState.completed);
        expect(
          result.artifact?.relativePath,
          'recordings/ios-native-recording.mp4',
        );
        expect(result.artifact?.sourcePath, '/tmp/ios-native-recording.mp4');
        expect(result.effectiveLayer, CockpitRecordingLayer.system);
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
    this.onStop,
  });

  final Future<CockpitRecordingSession> Function(
      CockpitRecordingRequest request)? onStart = null;
  final Future<CockpitRecordingResult> Function()? onStop;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
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
