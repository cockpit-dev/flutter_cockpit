import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/capture/cockpit_simctl_capture_adapter.dart';
import 'package:test/test.dart';

void main() {
  CockpitCommand captureCommand() {
    return CockpitCommand(
      commandId: 'simctl-capture',
      commandType: CockpitCommandType.captureScreenshot,
      screenshotRequest: const CockpitScreenshotRequest(
        reason: CockpitScreenshotReason.acceptance,
        name: 'simctl-home',
      ),
    );
  }

  test('simctl capture writes the screenshot artifact', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_simctl_capture_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final commands = <List<String>>[];

    final adapter = CockpitSimctlCaptureAdapter(
      deviceId: 'SIM-UDID',
      processRunner: (executable, arguments) async {
        commands.add(<String>[executable, ...arguments]);
        final outputPath = arguments.last;
        File(outputPath).writeAsBytesSync(<int>[137, 80, 78, 71]);
        return ProcessResult(0, 0, '', '');
      },
      tempFileFactory: (fileName) async => File('${tempDir.path}/$fileName'),
    );

    final execution = await adapter.capture(captureCommand());

    expect(execution.result.success, isTrue);
    expect(commands.single.take(4), <String>[
      'xcrun',
      'simctl',
      'io',
      'SIM-UDID',
    ]);
    expect(commands.single[4], 'screenshot');
    final artifact = execution.result.artifacts.single;
    final sourcePath = execution.artifactSourcePaths[artifact.relativePath];
    expect(sourcePath, isNotNull);
    expect(File(sourcePath!).existsSync(), isTrue);
  });

  test('simctl capture surfaces failures with stderr details', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_simctl_capture_fail_test',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final adapter = CockpitSimctlCaptureAdapter(
      deviceId: 'SIM-UDID',
      processRunner: (executable, arguments) async {
        return ProcessResult(0, 1, '', 'Invalid device: SIM-UDID');
      },
      tempFileFactory: (fileName) async => File('${tempDir.path}/$fileName'),
    );

    final execution = await adapter.capture(captureCommand());

    expect(execution.result.success, isFalse);
    expect(
      execution.result.error?.details['stderr'],
      contains('Invalid device'),
    );
  });
}
