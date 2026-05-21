import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/capture/cockpit_linux_capture_adapter.dart';
import 'package:flutter_cockpit_devtools/src/platform/linux/cockpit_linux_window_target.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('linux capture adapter falls back across host screenshot executables',
      () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_linux_capture_adapter',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final invocations = <String>[];
    final outputFile = File(p.join(tempDir.path, 'acceptance.png'));
    final adapter = CockpitLinuxCaptureAdapter(
      appId: 'cockpit_demo',
      processId: 5101,
      captureExecutables: const <String>['gnome-screenshot', 'grim'],
      windowTargetResolver: ({
        required appId,
        required processId,
        required processRunner,
        required timeout,
      }) async {
        expect(appId, 'cockpit_demo');
        expect(processId, 5101);
        return const CockpitLinuxWindowTarget(
          windowId: '0x02c00007',
          left: 120,
          top: 48,
          width: 900,
          height: 640,
        );
      },
      tempFileFactory: (_) async => outputFile,
      processRunner: (executable, arguments) async {
        invocations.add('$executable ${arguments.join(' ')}');
        if (executable == 'wmctrl') {
          return ProcessResult(0, 0, '', '');
        }
        if (executable == 'gnome-screenshot') {
          throw ProcessException(executable, arguments, 'missing', 127);
        }
        outputFile.writeAsStringSync('png-data');
        return ProcessResult(0, 0, '', '');
      },
      activationSettleDelay: Duration.zero,
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture-1',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'linux-acceptance',
          attachToStep: true,
        ),
      ),
    );

    expect(execution.result.success, isTrue);
    expect(
      execution.result.artifacts.single.relativePath,
      contains('screenshots/linux_acceptance_acceptance_'),
    );
    expect(outputFile.readAsStringSync(), 'png-data');
    expect(invocations.first, contains('wmctrl -ia 0x02c00007'));
    expect(invocations, contains('gnome-screenshot -w -f ${outputFile.path}'));
    expect(
      invocations,
      contains('grim -g 120,48 900x640 ${outputFile.path}'),
    );
  });

  test('linux capture adapter reports failure when no screenshot tool works',
      () async {
    final adapter = CockpitLinuxCaptureAdapter(
      appId: 'cockpit_demo',
      captureExecutables: const <String>['grim'],
      processRunner: (executable, arguments) async {
        throw ProcessException(executable, arguments, 'missing', 127);
      },
      activationSettleDelay: Duration.zero,
    );

    final execution = await adapter.capture(
      CockpitCommand(
        commandId: 'capture-2',
        commandType: CockpitCommandType.captureScreenshot,
        screenshotRequest: const CockpitScreenshotRequest(
          reason: CockpitScreenshotReason.acceptance,
          name: 'linux-failure',
        ),
      ),
    );

    expect(execution.result.success, isFalse);
    expect(
      execution.result.error?.message,
      'Linux host screenshot failed.',
    );
  });
}
