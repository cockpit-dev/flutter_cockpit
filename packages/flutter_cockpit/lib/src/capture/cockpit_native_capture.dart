import 'package:flutter/services.dart';

import '../control/cockpit_screenshot_request.dart';
import '../model/cockpit_artifact_ref.dart';
import '../runtime/cockpit_snapshot.dart';
import 'cockpit_captured_screenshot.dart';
import 'cockpit_capture_paths.dart';
import 'cockpit_capture_profile.dart';

final class CockpitNativeCapture {
  const CockpitNativeCapture({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'dev.cockpit.flutter_cockpit/capture';

  final MethodChannel _channel;

  Future<bool> queryAvailability() async {
    final payload = await _channel.invokeMethod<Object?>(
      'queryNativeCaptureAvailability',
    );
    if (payload is! bool) {
      throw StateError(
        'Native capture availability returned an invalid payload.',
      );
    }
    return payload;
  }

  Future<CockpitCapturedScreenshot> capture({
    required CockpitScreenshotRequest request,
    required CockpitCaptureProfile profile,
    CockpitSnapshot? snapshot,
  }) async {
    final payload = await _channel
        .invokeMethod<Object?>('captureAcceptanceScreenshot', <String, Object?>{
      'name': request.name,
      'reason': request.reason.jsonValue,
      'profile': profile.name,
    });

    if (payload is! Map<Object?, Object?>) {
      throw StateError('Native capture returned an invalid payload.');
    }

    final bytes = payload['bytes'];
    if (bytes is! Uint8List) {
      throw StateError('Native capture did not return PNG bytes.');
    }

    return CockpitCapturedScreenshot(
      artifact: CockpitArtifactRef(
        role: 'screenshot',
        relativePath: cockpitScreenshotRelativePathFor(request),
      ),
      bytes: bytes,
      snapshot: snapshot,
    );
  }
}
