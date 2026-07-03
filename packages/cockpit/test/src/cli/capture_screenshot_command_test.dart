import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/cli/commands/capture_screenshot_command.dart';
import 'package:test/test.dart';

void main() {
  test(
    'capture-screenshot maps concise CLI flags to screenshot request',
    () async {
      CockpitCaptureScreenshotRequest? capturedRequest;
      final stdoutBuffer = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          CaptureScreenshotCommand(
            stdoutSink: stdoutBuffer,
            capture: (request) async {
              capturedRequest = request;
              return const CockpitCaptureScreenshotResult(
                command: CockpitInteractiveCommandCore(
                  commandId: 'capture-screenshot',
                  commandType: 'captureScreenshot',
                  success: true,
                  durationMs: 42,
                  usedCaptureFallback: false,
                ),
                artifacts: <CockpitInteractiveArtifactDescriptor>[
                  CockpitInteractiveArtifactDescriptor(
                    role: 'screenshot',
                    relativePath:
                        'screenshots/20260412T101112_home_acceptance.png',
                    byteLength: 512,
                  ),
                ],
              );
            },
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'capture-screenshot',
            '--base-url',
            'http://127.0.0.1:47331',
            '--ios-device-id',
            '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
            '--name',
            'home',
            '--reason',
            'baseline',
            '--include-snapshot',
            '--no-attach-to-step',
            '--timeout-ms',
            '9000',
            '--profile',
            'evidence',
            '--stdout-format',
            'json',
          ]) ??
          0;

      expect(exitCode, 0);
      final request = capturedRequest;
      expect(request, isNotNull);
      expect(request!.baseUri, Uri.parse('http://127.0.0.1:47331'));
      expect(request.iosDeviceId, '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC');
      expect(request.name, 'home');
      expect(request.reason, CockpitScreenshotReason.baseline);
      expect(request.includeSnapshot, isTrue);
      expect(request.attachToStep, isFalse);
      expect(request.defaultCommandTimeout, const Duration(milliseconds: 9000));
      expect(request.resultProfile.name.jsonValue, 'evidence');

      final decoded =
          jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
      expect(decoded['command'], isA<Map<String, Object?>>());
      expect(decoded['artifacts'], isA<List<Object?>>());
    },
  );

  test(
    'capture-screenshot defaults to acceptance screenshot evidence',
    () async {
      CockpitCaptureScreenshotRequest? capturedRequest;
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          CaptureScreenshotCommand(
            stdoutSink: StringBuffer(),
            capture: (request) async {
              capturedRequest = request;
              return const CockpitCaptureScreenshotResult(
                command: CockpitInteractiveCommandCore(
                  commandId: 'capture-screenshot',
                  commandType: 'captureScreenshot',
                  success: true,
                  durationMs: 1,
                  usedCaptureFallback: false,
                ),
                artifacts: <CockpitInteractiveArtifactDescriptor>[],
              );
            },
          ),
        );

      final exitCode =
          await runner.run(<String>[
            'capture-screenshot',
            '--base-url',
            'http://127.0.0.1:47331',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.name, 'screenshot');
      expect(capturedRequest?.reason, CockpitScreenshotReason.acceptance);
      expect(capturedRequest?.includeSnapshot, isFalse);
      expect(capturedRequest?.attachToStep, isTrue);
      expect(capturedRequest?.resultProfile.name.jsonValue, 'standard');
    },
  );
}
