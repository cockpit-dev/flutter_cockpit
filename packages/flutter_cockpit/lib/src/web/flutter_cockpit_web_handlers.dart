import 'package:flutter/services.dart';

import '../recording/cockpit_recording_kind.dart';
import '../recording/cockpit_recording_state.dart';

const String cockpitWebCaptureChannelName =
    'dev.cockpit.flutter_cockpit/capture';
const String cockpitWebRecordingChannelName =
    'dev.cockpit.flutter_cockpit/recording';
const String cockpitWebNativeCaptureUnavailableMessage =
    'Native acceptance capture is unavailable on web. Use Flutter view capture instead.';
const String cockpitWebNativeRecordingUnavailableMessage =
    'Native in-app recording is unavailable on web. Use host-side recording through cockpit instead.';

Future<Object?> cockpitWebHandleCaptureMethodCall(MethodCall call) async {
  switch (call.method) {
    case 'queryNativeCaptureAvailability':
      return false;
    case 'captureAcceptanceScreenshot':
      throw PlatformException(
        code: 'nativeCaptureUnavailable',
        message: cockpitWebNativeCaptureUnavailableMessage,
      );
  }

  throw PlatformException(
    code: 'unimplemented',
    message: 'Method ${call.method} is not implemented on web.',
  );
}

Future<Object?> cockpitWebHandleRecordingMethodCall(MethodCall call) async {
  switch (call.method) {
    case 'queryRecordingCapabilities':
      return <String, Object?>{
        'supportsNativeRecording': false,
        'preferredAcceptanceRecordingKind':
            CockpitRecordingKind.nativeScreen.name,
        'supportedLayers': const <String>[],
        'recordingLimitations': <String>[
          cockpitWebNativeRecordingUnavailableMessage,
        ],
      };
    case 'startRecording':
      throw PlatformException(
        code: 'nativeRecordingUnavailable',
        message: cockpitWebNativeRecordingUnavailableMessage,
      );
    case 'stopRecording':
      return <String, Object?>{
        'state': CockpitRecordingState.failed.name,
        'recordingKind': CockpitRecordingKind.nativeScreen.name,
        'effectiveLayer': 'host-screen',
        'failureReason': 'recordingNotActive',
      };
  }

  throw PlatformException(
    code: 'unimplemented',
    message: 'Method ${call.method} is not implemented on web.',
  );
}
