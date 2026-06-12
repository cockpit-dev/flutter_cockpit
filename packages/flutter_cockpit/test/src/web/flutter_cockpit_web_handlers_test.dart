import 'package:flutter/services.dart';
import 'package:flutter_cockpit/src/web/flutter_cockpit_web_handlers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web capture reports native capture as unavailable', () async {
    final availability = await cockpitWebHandleCaptureMethodCall(
      const MethodCall('queryNativeCaptureAvailability'),
    );
    expect(availability, isFalse);
  });

  test('web capture rejects acceptance screenshots with a typed code', () {
    expect(
      () => cockpitWebHandleCaptureMethodCall(
        const MethodCall('captureAcceptanceScreenshot'),
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'nativeCaptureUnavailable',
        ),
      ),
    );
  });

  test('web capture rejects unknown methods as unimplemented', () {
    expect(
      () => cockpitWebHandleCaptureMethodCall(const MethodCall('unknown')),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'unimplemented',
        ),
      ),
    );
  });

  test('web recording capabilities disable native recording', () async {
    final payload =
        await cockpitWebHandleRecordingMethodCall(
              const MethodCall('queryRecordingCapabilities'),
            )
            as Map<String, Object?>;
    expect(payload['supportsNativeRecording'], isFalse);
    expect(payload['supportedLayers'], isEmpty);
    expect(payload['recordingLimitations'], isNotEmpty);
  });

  test('web recording rejects startRecording with a typed code', () {
    expect(
      () => cockpitWebHandleRecordingMethodCall(
        const MethodCall('startRecording'),
      ),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'nativeRecordingUnavailable',
        ),
      ),
    );
  });

  test('web recording stopRecording reports an inactive recording', () async {
    final payload =
        await cockpitWebHandleRecordingMethodCall(
              const MethodCall('stopRecording'),
            )
            as Map<String, Object?>;
    expect(payload['state'], 'failed');
    expect(payload['failureReason'], 'recordingNotActive');
  });

  test('web recording rejects unknown methods as unimplemented', () {
    expect(
      () => cockpitWebHandleRecordingMethodCall(const MethodCall('unknown')),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'unimplemented',
        ),
      ),
    );
  });
}
