import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/capture/cockpit_linux_capture_adapter.dart';
import 'package:cockpit/src/platform/linux/cockpit_linux_window_target.dart';
import 'package:cockpit/src/recording/cockpit_linux_recording_adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'linux capture adapter falls back across host screenshot executables',
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
        windowTargetResolver:
            ({
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
        matches(
          RegExp(
            r'^screenshots/\d{8}T\d{12}Z_linux_acceptance_acceptance\.png$',
          ),
        ),
      );
      expect(outputFile.readAsStringSync(), 'png-data');
      expect(invocations.first, contains('wmctrl -ia 0x02c00007'));
      expect(
        invocations,
        contains('gnome-screenshot -w -f ${outputFile.path}'),
      );
      expect(
        invocations,
        contains('grim -g 120,48 900x640 ${outputFile.path}'),
      );
    },
  );

  test(
    'linux capture adapter reports failure when no screenshot tool works',
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
      expect(execution.result.error?.message, 'Linux host screenshot failed.');
      expect(execution.result.error?.details['attempts'], isA<List<Object?>>());
    },
  );

  test(
    'linux capture adapter uses import root fallback without a window target',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_linux_import_root_capture',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final invocations = <String>[];
      final outputFile = File(p.join(tempDir.path, 'web-root.png'));
      final adapter = CockpitLinuxCaptureAdapter(
        appId: 'google-chrome',
        captureExecutables: const <String>['import'],
        windowActivatorExecutable: null,
        windowTargetResolver:
            ({
              required appId,
              required processId,
              required processRunner,
              required timeout,
            }) async {
              throw StateError('No visible Linux window was found for $appId.');
            },
        tempFileFactory: (_) async => outputFile,
        processRunner: (executable, arguments) async {
          invocations.add('$executable ${arguments.join(' ')}');
          if (executable == 'import') {
            outputFile.writeAsStringSync('root-png-data');
            return ProcessResult(0, 0, '', '');
          }
          fail('Unexpected executable: $executable');
        },
        activationSettleDelay: Duration.zero,
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture-web-root',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'web-root',
          ),
        ),
      );

      expect(execution.result.success, isTrue);
      expect(outputFile.readAsStringSync(), 'root-png-data');
      expect(invocations, <String>['import -window root ${outputFile.path}']);
    },
  );

  test(
    'linux capture adapter uses xwd and ffmpeg root fallback without a window target',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_linux_xwd_root_capture',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final invocations = <String>[];
      final outputFile = File(p.join(tempDir.path, 'web-root.png'));
      final adapter = CockpitLinuxCaptureAdapter(
        appId: 'google-chrome',
        captureExecutables: const <String>['xwd-ffmpeg'],
        windowActivatorExecutable: null,
        windowTargetResolver:
            ({
              required appId,
              required processId,
              required processRunner,
              required timeout,
            }) async {
              throw StateError('No visible Linux window was found for $appId.');
            },
        tempFileFactory: (_) async => outputFile,
        processRunner: (executable, arguments) async {
          invocations.add('$executable ${arguments.join(' ')}');
          if (executable == 'xwd') {
            final outIndex = arguments.indexOf('-out');
            expect(outIndex, isNonNegative);
            File(arguments[outIndex + 1]).writeAsStringSync('xwd-data');
            return ProcessResult(0, 0, '', '');
          }
          if (executable == 'ffmpeg') {
            outputFile.writeAsStringSync('converted-png-data');
            return ProcessResult(0, 0, '', '');
          }
          fail('Unexpected executable: $executable');
        },
        activationSettleDelay: Duration.zero,
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture-web-root',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'web-root',
          ),
        ),
      );

      expect(execution.result.success, isTrue);
      expect(outputFile.readAsStringSync(), 'converted-png-data');
      expect(invocations, hasLength(2));
      expect(invocations[0], startsWith('xwd -root -silent -out '));
      expect(invocations[1], startsWith('ffmpeg -y -loglevel error -i '));
      expect(
        outputFile.parent.listSync().whereType<File>().map((file) => file.path),
        <String>[outputFile.path],
      );
    },
  );

  test(
    'linux capture adapter skips target-only tools before xwd root fallback',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_linux_xwd_after_target_only_capture',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final invocations = <String>[];
      final outputFile = File(p.join(tempDir.path, 'web-root.png'));
      final adapter = CockpitLinuxCaptureAdapter(
        appId: 'google-chrome',
        captureExecutables: const <String>['grim', 'xwd-ffmpeg'],
        windowActivatorExecutable: null,
        windowTargetResolver:
            ({
              required appId,
              required processId,
              required processRunner,
              required timeout,
            }) async {
              throw StateError('No visible Linux window was found for $appId.');
            },
        tempFileFactory: (_) async => outputFile,
        processRunner: (executable, arguments) async {
          invocations.add('$executable ${arguments.join(' ')}');
          if (executable == 'xwd') {
            final outIndex = arguments.indexOf('-out');
            expect(outIndex, isNonNegative);
            File(arguments[outIndex + 1]).writeAsStringSync('xwd-data');
            return ProcessResult(0, 0, '', '');
          }
          if (executable == 'ffmpeg') {
            outputFile.writeAsStringSync('converted-png-data');
            return ProcessResult(0, 0, '', '');
          }
          fail('Unexpected executable: $executable');
        },
        activationSettleDelay: Duration.zero,
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture-web-root',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'web-root',
          ),
        ),
      );

      expect(execution.result.success, isTrue);
      expect(outputFile.readAsStringSync(), 'converted-png-data');
      expect(invocations, hasLength(2));
      expect(invocations[0], startsWith('xwd -root -silent -out '));
      expect(invocations[1], startsWith('ffmpeg -y -loglevel error -i '));
      expect(
        outputFile.parent.listSync().whereType<File>().map((file) => file.path),
        <String>[outputFile.path],
      );
    },
  );

  test(
    'linux capture adapter uses ffmpeg x11grab root fallback without xwd or import',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_linux_ffmpeg_root_capture',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final invocations = <String>[];
      final outputFile = File(p.join(tempDir.path, 'web-root.png'));
      final adapter = CockpitLinuxCaptureAdapter(
        appId: 'google-chrome',
        captureExecutables: const <String>[
          'grim',
          'xwd-ffmpeg',
          'ffmpeg-x11grab',
          'import',
        ],
        windowActivatorExecutable: null,
        displayConfigResolver: () async => const CockpitLinuxDisplayConfig(
          display: ':99',
          captureSize: '1280x720',
        ),
        windowTargetResolver:
            ({
              required appId,
              required processId,
              required processRunner,
              required timeout,
            }) async {
              throw StateError('No visible Linux window was found for $appId.');
            },
        tempFileFactory: (_) async => outputFile,
        processRunner: (executable, arguments) async {
          invocations.add('$executable ${arguments.join(' ')}');
          if (executable == 'xwd') {
            throw ProcessException(executable, arguments, 'missing', 127);
          }
          if (executable == 'ffmpeg') {
            outputFile.writeAsStringSync('ffmpeg-png-data');
            return ProcessResult(0, 0, '', '');
          }
          if (executable == 'import') {
            throw ProcessException(executable, arguments, 'missing', 127);
          }
          fail('Unexpected executable: $executable');
        },
        activationSettleDelay: Duration.zero,
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture-web-root',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'web-root',
          ),
        ),
      );

      expect(execution.result.success, isTrue);
      expect(outputFile.readAsStringSync(), 'ffmpeg-png-data');
      expect(invocations, hasLength(2));
      expect(invocations[0], startsWith('xwd -root -silent -out '));
      expect(
        invocations[1],
        'ffmpeg -y -loglevel error -f x11grab -video_size 1280x720 -i :99+0,0 -frames:v 1 ${outputFile.path}',
      );
    },
  );

  test(
    'linux capture adapter includes every failed screenshot attempt in diagnostics',
    () async {
      final adapter = CockpitLinuxCaptureAdapter(
        appId: 'google-chrome',
        captureExecutables: const <String>['grim', 'xwd-ffmpeg', 'import'],
        windowActivatorExecutable: null,
        displayConfigResolver: () async => const CockpitLinuxDisplayConfig(
          display: ':99',
          captureSize: '1280x720',
        ),
        windowTargetResolver:
            ({
              required appId,
              required processId,
              required processRunner,
              required timeout,
            }) async {
              throw StateError('No visible Linux window was found for $appId.');
            },
        processRunner: (executable, arguments) async {
          throw ProcessException(executable, arguments, 'missing', 127);
        },
        activationSettleDelay: Duration.zero,
      );

      final execution = await adapter.capture(
        CockpitCommand(
          commandId: 'capture-web-root',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: const CockpitScreenshotRequest(
            reason: CockpitScreenshotReason.acceptance,
            name: 'web-root',
          ),
        ),
      );

      expect(execution.result.success, isFalse);
      final attempts =
          execution.result.error?.details['attempts'] as List<Object?>?;
      expect(attempts, hasLength(3));
      expect(
        attempts,
        containsAll(<Object?>[
          containsPair('executable', 'grim'),
          containsPair('executable', 'xwd'),
          containsPair('executable', 'import'),
        ]),
      );
    },
  );
}
