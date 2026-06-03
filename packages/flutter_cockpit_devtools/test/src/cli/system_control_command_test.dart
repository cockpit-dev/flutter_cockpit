import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_system_capabilities_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_system_action_command.dart';
import 'package:flutter_cockpit_devtools/src/system_control/cockpit_system_control_service.dart';
import 'package:test/test.dart';

void main() {
  test(
    'read-system-capabilities writes AI-readable capability matrix by default',
    () async {
      final output = StringBuffer();
      CockpitSystemControlDescribeRequest? capturedRequest;
      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
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
      expect(output.toString(), contains('availableActions=[tap]'));
    },
  );

  test(
    'read-system-capabilities supports json stdout for jq pipelines',
    () async {
      final output = StringBuffer();
      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
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

  test('run-system-action forwards compact action payload', () async {
    final output = StringBuffer();
    CockpitSystemControlActionRequest? capturedRequest;
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
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
}
