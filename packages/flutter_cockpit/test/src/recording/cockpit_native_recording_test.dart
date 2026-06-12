import 'package:flutter/services.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit/src/recording/cockpit_native_recording.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channelName = 'dev.cockpit.flutter_cockpit/recording';

  test('queryCapabilities parses the native capability payload', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(channelName);
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'queryRecordingCapabilities');
      return <String, Object?>{
        'supportsNativeRecording': true,
        'preferredAcceptanceRecordingKind': 'nativeScreen',
        'supportedLayers': <String>['app-window', 'system'],
        'preferredLayer': 'system',
        'recordingLimitations': <String>['duration limited'],
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final capabilities = await const CockpitNativeRecording(
      channel: channel,
    ).queryCapabilities();

    expect(capabilities.supportsNativeRecording, isTrue);
    expect(
      capabilities.preferredAcceptanceRecordingKind,
      CockpitRecordingKind.nativeScreen,
    );
    expect(capabilities.supportedLayers, <CockpitRecordingLayer>[
      CockpitRecordingLayer.appWindow,
      CockpitRecordingLayer.system,
    ]);
    expect(capabilities.preferredLayer, CockpitRecordingLayer.system);
    expect(capabilities.recordingLimitations, <String>['duration limited']);
  });

  test('queryCapabilities rejects non-map payloads', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(channelName);
    messenger.setMockMethodCallHandler(channel, (call) async => 'invalid');
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await expectLater(
      const CockpitNativeRecording(channel: channel).queryCapabilities(),
      throwsStateError,
    );
  });

  test('startRecording sends the request payload and reads state', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(channelName);
    Map<Object?, Object?>? sentArguments;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'startRecording');
      sentArguments = call.arguments as Map<Object?, Object?>;
      return <String, Object?>{'state': 'recording'};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const request = CockpitRecordingRequest(
      purpose: CockpitRecordingPurpose.acceptance,
      name: 'checkout-flow',
      mode: CockpitRecordingMode.native,
      layer: CockpitRecordingLayer.system,
    );
    final session = await const CockpitNativeRecording(
      channel: channel,
    ).startRecording(request: request);

    expect(session.state, CockpitRecordingState.recording);
    expect(session.request, request);
    expect(sentArguments?['purpose'], 'acceptance');
    expect(sentArguments?['name'], 'checkout-flow');
    expect(sentArguments?['mode'], 'native');
    expect(sentArguments?['layer'], 'system');
    expect(sentArguments?['relativePath'], isA<String>());
  });

  test('stopRecording parses a completed recording payload', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(channelName);
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'stopRecording');
      return <String, Object?>{
        'state': 'completed',
        'recordingKind': 'nativeScreen',
        'effectiveLayer': 'system',
        'durationMs': 5200,
        'sourceFilePath': '/tmp/recording.mp4',
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const request = CockpitRecordingRequest(
      purpose: CockpitRecordingPurpose.acceptance,
      name: 'checkout-flow',
    );
    final result = await const CockpitNativeRecording(channel: channel)
        .stopRecording(
          session: const CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
        );

    expect(result.state, CockpitRecordingState.completed);
    expect(result.recordingKind, CockpitRecordingKind.nativeScreen);
    expect(result.effectiveLayer, CockpitRecordingLayer.system);
    expect(result.durationMs, 5200);
    expect(result.sourceFilePath, '/tmp/recording.mp4');
    expect(result.artifact, isNotNull);
    expect(result.artifact!.role, 'recording');
  });

  test('stopRecording surfaces native failure payloads', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel(channelName);
    messenger.setMockMethodCallHandler(channel, (call) async {
      return <String, Object?>{
        'state': 'failed',
        'recordingKind': 'nativeScreen',
        'failureReason': 'recordingNotActive',
      };
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    const request = CockpitRecordingRequest(
      purpose: CockpitRecordingPurpose.acceptance,
      name: 'checkout-flow',
    );
    final result = await const CockpitNativeRecording(channel: channel)
        .stopRecording(
          session: const CockpitRecordingSession(
            request: request,
            state: CockpitRecordingState.recording,
          ),
        );

    expect(result.state, CockpitRecordingState.failed);
    expect(result.failureReason, 'recordingNotActive');
    expect(result.artifact, isNull);
  });
}
