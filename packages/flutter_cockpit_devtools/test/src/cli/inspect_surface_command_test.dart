import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_inspect_surface_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/inspect_surface_command.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test('inspect-surface writes structured surface payload', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        InspectSurfaceCommand(
          stdoutSink: output,
          inspect: (_) async => CockpitInspectSurfaceResult(
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
            surfaceKind: CockpitSurfaceKind.flutterSemantic,
            selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
            recommendedNextStep: 'runNextCommand',
            routeName: '/details',
            diagnosticLevel: 'investigate',
            truncated: false,
          ),
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'inspect-surface',
          '--stdout-format',
          'json',
          '--target-json',
          '/tmp/target.json',
          '--profile',
          'inspect',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['surfaceKind'], 'flutterSemantic');
  });
}
