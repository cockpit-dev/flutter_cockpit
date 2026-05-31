import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  test(
    'capture screenshot service builds an AI-first screenshot command',
    () async {
      CockpitRunCommandRequest? capturedRequest;
      final service = CockpitCaptureScreenshotService(
        runCommand: (request) async {
          capturedRequest = request;
          return const CockpitCaptureScreenshotResult(
            command: CockpitInteractiveCommandCore(
              commandId: 'capture-screenshot',
              commandType: 'captureScreenshot',
              success: true,
              durationMs: 12,
              usedCaptureFallback: false,
            ),
            artifacts: <CockpitInteractiveArtifactDescriptor>[],
          );
        },
      );

      await service.capture(
        CockpitCaptureScreenshotRequest(
          baseUri: Uri.parse('http://127.0.0.1:47331'),
        ),
      );

      final request = capturedRequest;
      expect(request, isNotNull);
      expect(request!.baseUri, Uri.parse('http://127.0.0.1:47331'));
      expect(request.command.commandId, 'capture-screenshot');
      expect(request.command.commandType, CockpitCommandType.captureScreenshot);
      expect(request.resultProfile.name.jsonValue, 'standard');
      expect(request.defaultCommandTimeout, const Duration(seconds: 30));

      final screenshot = request.command.screenshotRequest;
      expect(screenshot, isNotNull);
      expect(screenshot!.reason, CockpitScreenshotReason.acceptance);
      expect(screenshot.name, 'screenshot');
      expect(screenshot.includeSnapshot, isFalse);
      expect(screenshot.attachToStep, isTrue);
    },
  );

  test(
    'capture screenshot service forwards explicit evidence options',
    () async {
      CockpitRunCommandRequest? capturedRequest;
      final service = CockpitCaptureScreenshotService(
        runCommand: (request) async {
          capturedRequest = request;
          return const CockpitCaptureScreenshotResult(
            command: CockpitInteractiveCommandCore(
              commandId: 'capture-screenshot',
              commandType: 'captureScreenshot',
              success: true,
              durationMs: 12,
              usedCaptureFallback: false,
            ),
            artifacts: <CockpitInteractiveArtifactDescriptor>[],
          );
        },
      );

      await service.capture(
        const CockpitCaptureScreenshotRequest(
          appHandlePath: '/tmp/app.json',
          androidDeviceId: 'emulator-5554',
          name: 'before edit',
          reason: CockpitScreenshotReason.baseline,
          includeSnapshot: true,
          attachToStep: false,
          resultProfile: CockpitInteractiveResultProfile.evidence(),
          defaultCommandTimeout: Duration(seconds: 9),
        ),
      );

      final request = capturedRequest!;
      expect(request.appHandlePath, '/tmp/app.json');
      expect(request.androidDeviceId, 'emulator-5554');
      expect(request.resultProfile.name.jsonValue, 'evidence');
      expect(request.defaultCommandTimeout, const Duration(seconds: 9));
      expect(request.command.screenshotRequest?.name, 'before edit');
      expect(
        request.command.screenshotRequest?.reason,
        CockpitScreenshotReason.baseline,
      );
      expect(request.command.screenshotRequest?.includeSnapshot, isTrue);
      expect(request.command.screenshotRequest?.attachToStep, isFalse);
    },
  );
}
