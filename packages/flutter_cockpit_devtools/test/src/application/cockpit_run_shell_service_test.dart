import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_run_shell_service.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test('run shell executes host commands and returns structured output',
      () async {
    final service = CockpitRunShellService(
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        return ProcessResult(0, 0, 'Dart SDK version: 3.10.8', '');
      },
    );

    final result = await service.run(
      const CockpitRunShellRequest(
        command: <String>['dart', '--version'],
      ),
    );

    expect(result.success, isTrue);
    expect(result.scope, 'host');
    expect(result.command, <String>['dart', '--version']);
    expect(result.recommendedNextStep, 'continue');
  });

  test('run shell executes android target commands through adb shell',
      () async {
    late String capturedExecutable;
    late List<String> capturedArguments;
    final service = CockpitRunShellService(
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        capturedExecutable = executable;
        capturedArguments = arguments;
        return ProcessResult(0, 0, '34', '');
      },
    );

    final result = await service.run(
      CockpitRunShellRequest(
        scope: 'target',
        target: CockpitTargetHandle(
          targetId: 'android-device',
          targetKind: CockpitTargetKind.device,
          platform: 'android',
          deviceId: 'emulator-5554',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'device',
          connection: const CockpitTargetConnection(
            baseUrl: 'http://127.0.0.1:57331',
          ),
          launchedAt: DateTime.utc(2026, 4, 11),
        ),
        command: const <String>['getprop', 'ro.build.version.sdk'],
      ),
    );

    expect(capturedExecutable, 'adb');
    expect(capturedArguments, <String>[
      '-s',
      'emulator-5554',
      'shell',
      'getprop',
      'ro.build.version.sdk',
    ]);
    expect(result.scope, 'android');
    expect(result.success, isTrue);
  });
}
