import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cockpit/src/application/cockpit_read_target_service.dart';
import 'package:cockpit/src/cli/cockpit_interactive_cli_support.dart';
import 'package:cockpit/src/cli/commands/read_target_command.dart';
import 'package:cockpit/src/targets/cockpit_target_handle.dart';
import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:test/test.dart';

void main() {
  test(
    'read-target reuses the default latest target handle when present',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_read_target_default',
      );
      final previousCurrent = Directory.current;
      Directory.current = tempDir;
      addTearDown(() async {
        Directory.current = previousCurrent;
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final defaultTargetFile = File(
        cockpitDefaultTargetHandlePath(tempDir.path),
      );
      await defaultTargetFile.parent.create(recursive: true);
      await defaultTargetFile.writeAsString(
        jsonEncode(_targetHandle().toJson()),
      );

      CockpitReadTargetRequest? capturedRequest;
      final runner = CommandRunner<int>('cockpit', 'test')
        ..addCommand(
          ReadTargetCommand(
            read: (request) async {
              capturedRequest = request;
              return CockpitReadTargetResult(
                target: _targetHandle(),
                capabilityProfile: _capabilityProfile(),
                foregroundSurface: CockpitSurfaceKind.flutterSemantic,
                selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
                fallbackTrail: const <CockpitPlaneKind>[],
                recommendedNextStep: 'runNextCommand',
              );
            },
          ),
        );

      final exitCode = await runner.run(<String>['read-target']) ?? 0;

      expect(exitCode, 0);
      expect(
        File(capturedRequest!.targetHandlePath!).resolveSymbolicLinksSync(),
        defaultTargetFile.resolveSymbolicLinksSync(),
      );
    },
  );

  test('read-target accepts target-json and minimal profile', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        ReadTargetCommand(
          stdoutSink: output,
          read: (_) async => CockpitReadTargetResult(
            target: CockpitTargetHandle(
              targetId: _targetHandle().targetId,
              targetKind: _targetHandle().targetKind,
              platform: _targetHandle().platform,
              deviceId: _targetHandle().deviceId,
              projectDir: _targetHandle().projectDir,
              target: _targetHandle().target,
              connection: _targetHandle().connection,
              launchedAt: _targetHandle().launchedAt,
            ),
            capabilityProfile: _capabilityProfile(),
            foregroundSurface: CockpitSurfaceKind.flutterSemantic,
            selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
            fallbackTrail: const <CockpitPlaneKind>[
              CockpitPlaneKind.nativeUiPlane,
            ],
            recommendedNextStep: 'runNextCommand',
          ),
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'read-target',
          '--stdout-format',
          'json',
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

CockpitTargetHandle _targetHandle() {
  return CockpitTargetHandle(
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
  );
}

CockpitCapabilityProfile _capabilityProfile() {
  return CockpitCapabilityProfile(
    targetKind: CockpitTargetKind.flutterApp,
    surfaceKinds: <CockpitSurfaceKind>{CockpitSurfaceKind.flutterSemantic},
    actionCapabilities: <CockpitActionCapability>{CockpitActionCapability.tap},
    evidenceCapabilities: <CockpitEvidenceCapability>{
      CockpitEvidenceCapability.flutterScreenshot,
    },
  );
}
