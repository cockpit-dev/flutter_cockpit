import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import '../recording/cockpit_recording_kind.dart';
import '../recording/cockpit_recording_state.dart';

const String _captureChannelName = 'dev.cockpit.flutter_cockpit/capture';
const String _recordingChannelName = 'dev.cockpit.flutter_cockpit/recording';
const String _nativeCaptureUnavailableMessage =
    'Native acceptance capture is unavailable on web. Use Flutter view capture instead.';
const String _nativeRecordingUnavailableMessage =
    'Native in-app recording is unavailable on web. Use host-side recording through flutter_cockpit_devtools instead.';

final class FlutterCockpitWeb {
  static void registerWith(Registrar registrar) {
    final captureChannel = MethodChannel(
      _captureChannelName,
      const StandardMethodCodec(),
      registrar,
    );
    final recordingChannel = MethodChannel(
      _recordingChannelName,
      const StandardMethodCodec(),
      registrar,
    );
    captureChannel.setMethodCallHandler(_handleCaptureMethodCall);
    recordingChannel.setMethodCallHandler(_handleRecordingMethodCall);
  }

  static Future<Object?> _handleCaptureMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'queryNativeCaptureAvailability':
        return false;
      case 'captureAcceptanceScreenshot':
        throw PlatformException(
          code: 'nativeCaptureUnavailable',
          message: _nativeCaptureUnavailableMessage,
        );
    }

    throw PlatformException(
      code: 'unimplemented',
      message: 'Method ${call.method} is not implemented on web.',
    );
  }

  static Future<Object?> _handleRecordingMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'queryRecordingCapabilities':
        return <String, Object?>{
          'supportsNativeRecording': false,
          'preferredAcceptanceRecordingKind':
              CockpitRecordingKind.nativeScreen.name,
          'supportedLayers': const <String>[],
          'recordingLimitations': <String>[_nativeRecordingUnavailableMessage],
        };
      case 'startRecording':
        throw PlatformException(
          code: 'nativeRecordingUnavailable',
          message: _nativeRecordingUnavailableMessage,
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
}
