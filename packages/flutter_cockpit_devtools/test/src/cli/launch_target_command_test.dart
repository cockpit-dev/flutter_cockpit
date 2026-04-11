import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/launch_target_command.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_target_service.dart';
import 'package:flutter_cockpit_devtools/src/targets/cockpit_target_handle.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('launch-target writes normalized target payload', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchTargetCommand(
          stdoutSink: output,
          launch: (_) async => CockpitLaunchTargetResult(
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
          ),
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-target',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--platform',
          'android',
          '--device-id',
          'emulator-5554',
          '--session-port',
          '57331',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['target'], isA<Map<String, Object?>>());
  });
}
