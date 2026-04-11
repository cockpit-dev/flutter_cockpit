import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_target_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_target_command.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_handle.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('read-target accepts target-json and minimal profile', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        ReadTargetCommand(
          stdoutSink: output,
          read: (_) async => CockpitReadTargetResult(
            target: CockpitTargetHandle(
              targetId: 'dev.cockpit.demo',
              targetKind: CockpitTargetKind.flutterApp,
              platform: 'android',
              deviceId: 'emulator-5554',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              connection: const CockpitTargetConnection(
                baseUrl: 'http://127.0.0.1:57331',
              ),
              launchedAt: DateTime.utc(2026, 4, 11),
            ),
            capabilityProfile: CockpitCapabilityProfile(
              targetKind: CockpitTargetKind.flutterApp,
              surfaceKinds: <CockpitSurfaceKind>{
                CockpitSurfaceKind.flutterSemantic,
              },
              actionCapabilities: <CockpitActionCapability>{
                CockpitActionCapability.tap,
              },
              evidenceCapabilities: <CockpitEvidenceCapability>{
                CockpitEvidenceCapability.flutterScreenshot,
              },
            ),
            foregroundSurface: CockpitSurfaceKind.flutterSemantic,
            selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
            fallbackTrail: const <CockpitPlaneKind>[
              CockpitPlaneKind.nativeUiPlane,
            ],
            recommendedNextStep: 'runNextCommand',
          ),
        ),
      );

    final exitCode = await runner.run(<String>[
          'read-target',
          '--target-json',
          '/tmp/target.json',
          '--profile',
          'minimal',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['selectedPlane'], 'flutterSemanticPlane');
  });
}
