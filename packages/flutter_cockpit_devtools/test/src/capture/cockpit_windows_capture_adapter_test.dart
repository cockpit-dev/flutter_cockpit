import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/capture/cockpit_windows_capture_adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
      'windows capture adapter runs powershell capture and writes a screenshot',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_windows_capture_adapter',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final invocations = <String>[];
    final outputFile = File(p.join(tempDir.path, 'acceptance.png'));
    final adapter = CockpitWindowsCaptureAdapter(
      appId: 'cockpit_demo',
      tempFileFactory: (_) async => outputFile,
      processRunner: (executable, arguments) async {
        invocations.add('$executable ${arguments.join(' ')}');
        outputFile.writeAsStringSync('png-data');
        return ProcessResult(0, 0, '', '');
      },
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture-1',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'windows-acceptance',
          attachToStep: true,
        ),
      ),
    );

    expect(execution.result.success, isTrue);
    expect(
      execution.result.artifacts.single.relativePath,
      contains('screenshots/windows_acceptance_acceptance_'),
    );
    expect(execution.artifactSourcePaths, isNotEmpty);
    expect(outputFile.readAsStringSync(), 'png-data');
    expect(invocations.single, contains('powershell'));
    expect(invocations.single, contains('System.Windows.Forms'));
    expect(invocations.single, contains('cockpit_demo'));
  });

  test('windows capture adapter times out stalled powershell capture',
      () async {
    final adapter = CockpitWindowsCaptureAdapter(
      appId: 'cockpit_demo',
      timeout: const Duration(milliseconds: 50),
      processRunner: (executable, arguments) {
        return Future<ProcessResult>.delayed(
          const Duration(milliseconds: 150),
          () => ProcessResult(0, 0, '', ''),
        );
      },
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture-2',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'windows-timeout',
        ),
      ),
    );

    expect(execution.result.success, isFalse);
    expect(
      execution.result.error?.message,
      'Windows host screenshot timed out.',
    );
  });
}
