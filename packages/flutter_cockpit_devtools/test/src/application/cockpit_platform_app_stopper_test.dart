import 'dart:io';

import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_platform_app_stopper.dart';
import 'package:flutter_cockpit_devtools/src/platform/ios/cockpit_ios_device_process.dart';
import 'package:test/test.dart';

void main() {
  test('uses devicectl termination for physical iOS apps', () async {
    final invocations = <String>[];
    final stopper = CockpitPlatformAppStopper(
      processRunner: (executable, arguments) async {
        invocations.add('$executable ${arguments.join(' ')}');
        return ProcessResult(0, 0, '', '');
      },
      iosDeviceProcessTerminator: CockpitIosDeviceProcessTerminator(
        processRunner: (executable, arguments, {String? workingDirectory}) async {
          invocations.add('$executable ${arguments.join(' ')}');
          if (arguments.length >= 4 &&
              arguments[0] == 'devicectl' &&
              arguments[1] == 'device' &&
              arguments[2] == 'info' &&
              arguments[3] == 'processes') {
            final outputPath =
                arguments[arguments.indexOf('--json-output') + 1];
            final file = File(outputPath);
            await file.parent.create(recursive: true);
            await file.writeAsString(
              '{"result":{"processes":[{"processIdentifier":1201,"application":{"bundleIdentifier":"dev.example.target"}}]}}',
            );
          }
          return ProcessResult(0, 0, '', '');
        },
      ),
    );

    await stopper.stop(
      CockpitAppHandle(
        appId: 'dev.example.target',
        mode: CockpitAppMode.automation,
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
        projectDir: '/workspace/app',
        target: 'cockpit/main.dart',
        baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
        launchedAt: DateTime.utc(2026, 4, 15),
        platformAppId: 'dev.example.target',
      ),
    );

    expect(
      invocations,
      contains(
        'xcrun devicectl device process terminate --device 00008110-0009341C2EF3801E --pid 1201 --kill',
      ),
    );
    expect(
      invocations.where((command) => command.contains('simctl terminate')),
      isEmpty,
    );
  });

  test(
    'does not attempt physical iOS termination when platform bundle id is unknown',
    () async {
      final invocations = <String>[];
      final stopper = CockpitPlatformAppStopper(
        processRunner: (executable, arguments) async {
          invocations.add('$executable ${arguments.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
        iosDeviceProcessTerminator: CockpitIosDeviceProcessTerminator(
          processRunner:
              (executable, arguments, {String? workingDirectory}) async {
                invocations.add('$executable ${arguments.join(' ')}');
                return ProcessResult(0, 0, '', '');
              },
        ),
      );

      await stopper.stop(
        CockpitAppHandle(
          appId: 'remote-session-1',
          mode: CockpitAppMode.automation,
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          projectDir: '/workspace/app',
          target: 'cockpit/main.dart',
          baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
          launchedAt: DateTime.utc(2026, 4, 15),
        ),
      );

      expect(invocations, isEmpty);
    },
  );

  test('fails fast for unsupported web automation stops', () {
    final stopper = CockpitPlatformAppStopper();

    expect(
      () => stopper.stop(
        CockpitAppHandle(
          appId: 'dev.example.web',
          mode: CockpitAppMode.automation,
          platform: 'web',
          deviceId: 'chrome',
          projectDir: '/workspace/app',
          target: 'web/main.dart',
          baseUrl: 'http://127.0.0.1:57331',
          launchedAt: DateTime.utc(2026, 4, 15),
        ),
      ),
      throwsA(
        isA<CockpitApplicationServiceException>()
            .having(
              (error) => error.code,
              'code',
              'unsupportedAutomationPlatform',
            )
            .having(
              (error) => error.details['operation'],
              'operation',
              'stopApp',
            ),
      ),
    );
  });

  test('uses process id for windows automation apps when available', () async {
    final invocations = <String>[];
    final stopper = CockpitPlatformAppStopper(
      processRunner: (executable, arguments) async {
        invocations.add('$executable ${arguments.join(' ')}');
        return ProcessResult(0, 0, '', '');
      },
    );

    await stopper.stop(
      CockpitAppHandle(
        appId: 'cockpit_demo',
        mode: CockpitAppMode.automation,
        platform: 'windows',
        deviceId: 'windows',
        projectDir: '/workspace/app',
        target: 'cockpit/main.dart',
        baseUrl: 'http://127.0.0.1:57331',
        launchedAt: DateTime.utc(2026, 4, 17),
        processId: 4101,
      ),
    );

    expect(invocations, contains('taskkill /PID 4101 /T /F'));
    expect(
      invocations.where((command) => command.contains('/IM cockpit_demo.exe')),
      isEmpty,
    );
  });

  test('uses process id for linux automation apps when available', () async {
    final invocations = <String>[];
    final stopper = CockpitPlatformAppStopper(
      processRunner: (executable, arguments) async {
        invocations.add('$executable ${arguments.join(' ')}');
        return ProcessResult(0, 0, '', '');
      },
    );

    await stopper.stop(
      CockpitAppHandle(
        appId: 'cockpit_demo',
        mode: CockpitAppMode.automation,
        platform: 'linux',
        deviceId: 'linux',
        projectDir: '/workspace/app',
        target: 'cockpit/main.dart',
        baseUrl: 'http://127.0.0.1:57331',
        launchedAt: DateTime.utc(2026, 4, 17),
        processId: 5101,
      ),
    );

    expect(invocations, contains('kill -TERM 5101'));
    expect(
      invocations.where((command) => command.contains('pkill -x cockpit_demo')),
      isEmpty,
    );
  });
}
