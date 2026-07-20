import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/cli/commands/read_system_capabilities_command.dart';
import 'package:cockpit/src/cli/commands/run_system_action_command.dart';
import 'package:cockpit/src/system_control/cockpit_system_control_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'read-system-capabilities writes AI-readable capability matrix by default',
    () async {
      final output = StringBuffer();
      CockpitSystemControlDescribeRequest? capturedRequest;
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          ReadSystemCapabilitiesCommand(
            stdoutSink: output,
            describe: (request) async {
              capturedRequest = request;
              return const CockpitSystemControlDescribeResult(
                profile: CockpitSystemControlProfile(
                  platform: 'android',
                  deviceId: 'emulator-5554',
                  appId: 'dev.cockpit.example',
                  processId: 4242,
                  adapter: 'android.adb',
                  preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
                  fallbackOrder: <CockpitPlaneKind>[
                    CockpitPlaneKind.flutterSemanticPlane,
                    CockpitPlaneKind.nativeUiPlane,
                    CockpitPlaneKind.deviceSystemPlane,
                  ],
                  capabilities: <CockpitSystemControlCapability>[
                    CockpitSystemControlCapability(
                      action: CockpitSystemControlAction.tap,
                      plane: CockpitPlaneKind.deviceSystemPlane,
                      availability: CockpitSystemControlAvailability.available,
                      strategy: 'adb.shell.input.tap',
                    ),
                  ],
                  recommendedNextStep: 'preferFlutterSemanticPlane',
                ),
                recommendedNextStep: 'preferFlutterSemanticPlane',
              );
            },
          ),
        );

      final exitCode =
          await runner.run(const <String>[
            'read-system-capabilities',
            '--platform',
            'android',
            '--device-id',
            'emulator-5554',
            '--app-id',
            'dev.cockpit.example',
            '--process-id',
            '4242',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.appId, 'dev.cockpit.example');
      expect(capturedRequest?.processId, 4242);
      expect(output.toString(), contains('cockpit.v=1'));
      expect(output.toString(), contains('command=read-system-capabilities'));
      expect(output.toString(), contains('platform=android'));
      expect(output.toString(), contains('appId=dev.cockpit.example'));
      expect(output.toString(), contains('processId=4242'));
      expect(output.toString(), contains('next=preferFlutterSemanticPlane'));
      expect(output.toString(), contains('availableActions=tap'));
      expect(
        output.toString(),
        contains('[0] action=tap availability=available'),
      );
    },
  );

  test(
    'read-system-capabilities supports json stdout for jq pipelines',
    () async {
      final output = StringBuffer();
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          ReadSystemCapabilitiesCommand(
            stdoutSink: output,
            describe: (_) async => const CockpitSystemControlDescribeResult(
              profile: CockpitSystemControlProfile(
                platform: 'ios',
                deviceId: '00008110-001234',
                adapter: 'ios.physical',
                preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
                fallbackOrder: <CockpitPlaneKind>[
                  CockpitPlaneKind.flutterSemanticPlane,
                  CockpitPlaneKind.nativeUiPlane,
                ],
                capabilities: <CockpitSystemControlCapability>[
                  CockpitSystemControlCapability(
                    action: CockpitSystemControlAction.tap,
                    plane: CockpitPlaneKind.nativeUiPlane,
                    availability: CockpitSystemControlAvailability.blocked,
                    strategy: 'xctest.webdriveragent',
                    requires: <String>[
                      'developer-signed XCTest/WebDriverAgent runner',
                    ],
                  ),
                ],
                recommendedNextStep: 'preferFlutterSemanticPlane',
              ),
              recommendedNextStep: 'preferFlutterSemanticPlane',
            ),
          ),
        );

      final exitCode =
          await runner.run(const <String>[
            'read-system-capabilities',
            '--platform',
            'ios',
            '--device-id',
            '00008110-001234',
            '--stdout-format',
            'json',
          ]) ??
          0;

      expect(exitCode, 0);
      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(decoded['platform'], 'ios');
      expect(decoded['adapter'], 'ios.physical');
      expect(decoded['blockedActions'], contains('tap'));
    },
  );

  test(
    'read-system-capabilities maps explicit cockpit app id to platform app id',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_system_capabilities_app_id_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeDefaultAppHandle(
        tempDir,
        appId: 'remote-session-1',
        platformAppId: 'dev.cockpit.example',
      );
      final output = StringBuffer();
      CockpitSystemControlDescribeRequest? capturedRequest;
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          ReadSystemCapabilitiesCommand(
            stdoutSink: output,
            describe: (request) async {
              capturedRequest = request;
              return const CockpitSystemControlDescribeResult(
                profile: CockpitSystemControlProfile(
                  platform: 'ios',
                  deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
                  appId: 'dev.cockpit.example',
                  adapter: 'ios.simctl+xctest',
                  preferredPlane: CockpitPlaneKind.flutterSemanticPlane,
                  fallbackOrder: <CockpitPlaneKind>[
                    CockpitPlaneKind.flutterSemanticPlane,
                    CockpitPlaneKind.deviceSystemPlane,
                  ],
                  capabilities: <CockpitSystemControlCapability>[],
                  recommendedNextStep: 'preferFlutterSemanticPlane',
                ),
                recommendedNextStep: 'preferFlutterSemanticPlane',
              );
            },
          ),
        );
      final previousDirectory = Directory.current;
      Directory.current = tempDir;
      addTearDown(() {
        Directory.current = previousDirectory;
      });

      final exitCode =
          await runner.run(const <String>[
            'read-system-capabilities',
            '--app-id',
            'remote-session-1',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.appId, 'dev.cockpit.example');
    },
  );

  test('run-system-action forwards compact action payload', () async {
    final output = StringBuffer();
    CockpitSystemControlActionRequest? capturedRequest;
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        RunSystemActionCommand(
          stdoutSink: output,
          runAction: (request) async {
            capturedRequest = request;
            return const CockpitSystemControlActionResult(
              platform: 'android',
              deviceId: 'emulator-5554',
              action: CockpitSystemControlAction.tap,
              availability: CockpitSystemControlAvailability.available,
              success: true,
              command: <String>[
                'adb',
                '-s',
                'emulator-5554',
                'shell',
                'input',
                'tap',
                '42',
                '88',
              ],
              recommendedNextStep: 'readPostActionState',
            );
          },
        ),
      );

    final exitCode =
        await runner.run(const <String>[
          'run-system-action',
          '--platform',
          'android',
          '--device-id',
          'emulator-5554',
          '--app-id',
          'dev.cockpit.example',
          '--process-id',
          '4242',
          '--action',
          'tap',
          '--x',
          '42',
          '--y',
          '88',
          '--stdout-format',
          'json',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.platform, 'android');
    expect(capturedRequest?.deviceId, 'emulator-5554');
    expect(capturedRequest?.appId, 'dev.cockpit.example');
    expect(capturedRequest?.processId, 4242);
    expect(capturedRequest?.action, CockpitSystemControlAction.tap);
    expect(capturedRequest?.parameters['x'], 42);
    expect(capturedRequest?.parameters['y'], 88);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['success'], isTrue);
    expect(decoded['recommendedNextStep'], 'readPostActionState');
  });

  test(
    'run-system-action maps explicit cockpit app id to platform app id',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_system_action_app_id_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeDefaultAppHandle(
        tempDir,
        appId: 'remote-session-1',
        platformAppId: 'dev.cockpit.example',
      );
      final output = StringBuffer();
      CockpitSystemControlActionRequest? capturedRequest;
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          RunSystemActionCommand(
            stdoutSink: output,
            runAction: (request) async {
              capturedRequest = request;
              return const CockpitSystemControlActionResult(
                platform: 'ios',
                deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
                appId: 'dev.cockpit.example',
                action: CockpitSystemControlAction.recoverToApp,
                availability: CockpitSystemControlAvailability.available,
                success: true,
                recommendedNextStep: 'readPostActionState',
              );
            },
          ),
        );
      final previousDirectory = Directory.current;
      Directory.current = tempDir;
      addTearDown(() {
        Directory.current = previousDirectory;
      });

      final exitCode =
          await runner.run(const <String>[
            'run-system-action',
            '--app-id',
            'remote-session-1',
            '--action',
            'recoverToApp',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.appId, 'dev.cockpit.example');
    },
  );

  test(
    'run-system-action reuses the default app handle and forwards WebDriverAgent metadata',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_system_command_default_app_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      await _writeDefaultAppHandle(
        tempDir,
        appId: 'remote-session-1',
        platformAppId: 'dev.cockpit.example',
      );
      final output = StringBuffer();
      CockpitSystemControlActionRequest? capturedRequest;
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          RunSystemActionCommand(
            stdoutSink: output,
            runAction: (request) async {
              capturedRequest = request;
              return const CockpitSystemControlActionResult(
                platform: 'ios',
                deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
                appId: 'dev.cockpit.example',
                action: CockpitSystemControlAction.dismissSystemDialog,
                availability: CockpitSystemControlAvailability.available,
                success: true,
                recommendedNextStep: 'readPostActionState',
              );
            },
          ),
        );
      final previousDirectory = Directory.current;
      Directory.current = tempDir;
      addTearDown(() {
        Directory.current = previousDirectory;
      });

      final exitCode =
          await runner.run(const <String>[
            'run-system-action',
            '--action',
            'dismissSystemDialog',
            '--wda-url',
            'http://127.0.0.1:8100',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.platform, 'ios');
      expect(capturedRequest?.deviceId, '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC');
      expect(capturedRequest?.appId, 'dev.cockpit.example');
      expect(capturedRequest?.metadata['wdaUrl'], 'http://127.0.0.1:8100');
    },
  );

  test('run-system-action forwards key payload without JSON', () async {
    final output = StringBuffer();
    CockpitSystemControlActionRequest? capturedRequest;
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        RunSystemActionCommand(
          stdoutSink: output,
          runAction: (request) async {
            capturedRequest = request;
            return const CockpitSystemControlActionResult(
              platform: 'android',
              deviceId: 'emulator-5554',
              action: CockpitSystemControlAction.pressKey,
              availability: CockpitSystemControlAvailability.available,
              success: true,
              recommendedNextStep: 'readPostActionState',
            );
          },
        ),
      );

    final exitCode =
        await runner.run(const <String>[
          'run-system-action',
          '--platform',
          'android',
          '--device-id',
          'emulator-5554',
          '--action',
          'pressKey',
          '--key',
          'KEYCODE_ENTER',
          '--decision',
          'dismiss',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.action, CockpitSystemControlAction.pressKey);
    expect(capturedRequest?.parameters['key'], 'KEYCODE_ENTER');
    expect(capturedRequest?.parameters['decision'], 'dismiss');
    expect(output.toString(), contains('status=ok'));
    expect(output.toString(), contains('action=pressKey'));
  });

  test('run-system-action forwards environment payload without JSON', () async {
    final output = StringBuffer();
    CockpitSystemControlActionRequest? capturedRequest;
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        RunSystemActionCommand(
          stdoutSink: output,
          runAction: (request) async {
            capturedRequest = request;
            return const CockpitSystemControlActionResult(
              platform: 'ios',
              deviceId: 'booted',
              action: CockpitSystemControlAction.setLocation,
              availability: CockpitSystemControlAvailability.available,
              success: true,
              recommendedNextStep: 'readPostActionState',
            );
          },
        ),
      );

    final exitCode =
        await runner.run(const <String>[
          'run-system-action',
          '--platform',
          'ios',
          '--device-id',
          'booted',
          '--action',
          'setLocation',
          '--settings-action',
          'android.settings.SETTINGS',
          '--appearance',
          'dark',
          '--content-size',
          'accessibility-large',
          '--font-scale',
          '1.8',
          '--latitude',
          '37.3349',
          '--longitude',
          '-122.009',
          '--altitude',
          '15',
          '--orientation',
          'landscape',
          '--network-speed',
          'full',
          '--network-delay',
          'none',
          '--time',
          '09:41',
          '--data-network',
          'wifi',
          '--wifi-mode',
          'active',
          '--wifi-bars',
          '3',
          '--cellular-mode',
          'notSupported',
          '--cellular-bars',
          '0',
          '--operator-name',
          'Cockpit',
          '--battery-state',
          'charged',
          '--battery-level',
          '100',
          '--title',
          'Download complete',
          '--body',
          'Model is ready',
          '--tag',
          'model-download',
          '--payload-json',
          '{"aps":{"alert":"Ready"}}',
          '--max-depth',
          '3',
          '--max-nodes',
          '40',
          '--name',
          'system-flow',
          '--purpose',
          'repro',
          '--mode',
          'native',
          '--layer',
          'system',
          '--output-path',
          '/tmp/system-flow.mp4',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.action, CockpitSystemControlAction.setLocation);
    expect(capturedRequest?.parameters['appearance'], 'dark');
    expect(
      capturedRequest?.parameters['settingsAction'],
      'android.settings.SETTINGS',
    );
    expect(capturedRequest?.parameters['contentSize'], 'accessibility-large');
    expect(capturedRequest?.parameters['fontScale'], '1.8');
    expect(capturedRequest?.parameters['latitude'], '37.3349');
    expect(capturedRequest?.parameters['longitude'], '-122.009');
    expect(capturedRequest?.parameters['altitude'], '15');
    expect(capturedRequest?.parameters['orientation'], 'landscape');
    expect(capturedRequest?.parameters['networkSpeed'], 'full');
    expect(capturedRequest?.parameters['networkDelay'], 'none');
    expect(capturedRequest?.parameters['time'], '09:41');
    expect(capturedRequest?.parameters['dataNetwork'], 'wifi');
    expect(capturedRequest?.parameters['wifiMode'], 'active');
    expect(capturedRequest?.parameters['wifiBars'], 3);
    expect(capturedRequest?.parameters['cellularMode'], 'notSupported');
    expect(capturedRequest?.parameters['cellularBars'], 0);
    expect(capturedRequest?.parameters['operatorName'], 'Cockpit');
    expect(capturedRequest?.parameters['batteryState'], 'charged');
    expect(capturedRequest?.parameters['batteryLevel'], 100);
    expect(capturedRequest?.parameters['title'], 'Download complete');
    expect(capturedRequest?.parameters['body'], 'Model is ready');
    expect(capturedRequest?.parameters['tag'], 'model-download');
    expect(
      capturedRequest?.parameters['payloadJson'],
      '{"aps":{"alert":"Ready"}}',
    );
    expect(capturedRequest?.parameters['maxDepth'], 3);
    expect(capturedRequest?.parameters['maxNodes'], 40);
    expect(capturedRequest?.parameters['name'], 'system-flow');
    expect(capturedRequest?.parameters['purpose'], 'repro');
    expect(capturedRequest?.parameters['mode'], 'native');
    expect(capturedRequest?.parameters['layer'], 'system');
    expect(capturedRequest?.parameters['outputPath'], '/tmp/system-flow.mp4');
  });
}

Future<void> _writeDefaultAppHandle(
  Directory tempDir, {
  required String appId,
  required String platformAppId,
}) async {
  final appHandleFile = File(
    p.join(tempDir.path, '.dart_tool', 'flutter_cockpit', 'latest_app.json'),
  );
  await appHandleFile.parent.create(recursive: true);
  await appHandleFile.writeAsString(
    jsonEncode(<String, Object?>{
      'appId': appId,
      'mode': 'development',
      'platform': 'ios',
      'deviceId': '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      'projectDir': tempDir.path,
      'target': 'cockpit/main.dart',
      'baseUrl': 'http://127.0.0.1:57331',
      'launchedAt': '2026-06-09T00:00:00.000Z',
      'platformAppId': platformAppId,
    }),
  );
}
