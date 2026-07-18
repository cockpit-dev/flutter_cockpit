import 'package:cockpit/src/capture/cockpit_host_capture_adapter.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('host capture reports its actual source and requested profile', () {
    final execution = cockpitSuccessfulHostCaptureExecution(
      command: CockpitCommand(
        commandId: 'capture',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'system-proof',
          profile: CockpitCaptureProfile.nativePreferred,
        ),
      ),
      artifact: const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/system-proof.png',
      ),
      durationMs: 4,
      sourceFilePath: '/tmp/system-proof.png',
    );

    expect(
      execution.result.requestedCaptureProfile,
      CockpitCaptureProfile.nativePreferred,
    );
    expect(execution.result.resolvedCaptureKind, CockpitCaptureKind.hostSystem);
  });
}
