import 'dart:io';

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

  test('host capture validation rejects and deletes an empty file', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_host_capture_empty_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final outputFile = File('${tempDir.path}/empty.png')..createSync();

    final execution = await cockpitValidateHostCaptureOutput(
      command: _captureCommand(),
      artifact: const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/empty.png',
      ),
      durationMs: 4,
      outputFile: outputFile,
      captureDescription: 'test capture',
    );

    expect(execution.result.success, isFalse);
    expect(execution.result.error?.message, contains('empty PNG artifact'));
    expect(
      execution.result.error?.details['validationCode'],
      'screenshotEmpty',
    );
    expect(outputFile.existsSync(), isFalse);
  });

  test('host capture validation truthfully reports a missing file', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_host_capture_missing_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final outputFile = File('${tempDir.path}/missing.png');

    final execution = await cockpitValidateHostCaptureOutput(
      command: _captureCommand(),
      artifact: const CockpitArtifactRef(
        role: 'screenshot',
        relativePath: 'screenshots/missing.png',
      ),
      durationMs: 4,
      outputFile: outputFile,
      captureDescription: 'test capture',
    );

    expect(execution.result.success, isFalse);
    expect(
      execution.result.error?.message,
      'test capture did not produce a PNG artifact.',
    );
    expect(execution.artifactSourcePaths, isEmpty);
  });
}

CockpitCommand _captureCommand() => CockpitCommand(
  commandId: 'capture',
  commandType: CockpitCommandType.captureScreenshot,
  screenshotRequest: const CockpitScreenshotRequest(
    reason: CockpitScreenshotReason.acceptance,
    name: 'host-capture',
  ),
);
