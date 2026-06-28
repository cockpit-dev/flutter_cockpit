import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/cli/commands/launch_target_command.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:test/test.dart';

void main() {
  test('launch-target writes normalized target payload', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
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

    final exitCode =
        await runner.run(<String>[
          'launch-target',
          '--stdout-format',
          'json',
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

  test('launch-target forwards launch configuration flags', () async {
    CockpitLaunchTargetRequest? capturedRequest;
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        LaunchTargetCommand(
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchTargetResult(
              target: CockpitTargetHandle(
                targetId: 'dev.cockpit.demo',
                targetKind: CockpitTargetKind.flutterApp,
                platform: 'android',
                deviceId: 'emulator-5554',
                projectDir: request.projectDir,
                target: request.target ?? 'cockpit/main.dart',
                connection: const CockpitTargetConnection(
                  baseUrl: 'http://127.0.0.1:57331',
                ),
                launchedAt: DateTime.utc(2026, 4, 11),
              ),
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'launch-target',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--platform',
          'android',
          '--device-id',
          'emulator-5554',
          '--dart-define',
          'API_URL=https://example.test',
          '--dart-define-from-file',
          'config/dev.json',
          '--flutter-arg',
          '--track-widget-creation',
          '--env',
          'API_TOKEN=secret',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.launchConfiguration.dartDefines, <String>[
      'API_URL=https://example.test',
    ]);
    expect(capturedRequest?.launchConfiguration.dartDefineFromFiles, <String>[
      'config/dev.json',
    ]);
    expect(capturedRequest?.launchConfiguration.flutterArgs, <String>[
      '--track-widget-creation',
    ]);
    expect(capturedRequest?.launchConfiguration.environment, <String, String>{
      'API_TOKEN': 'secret',
    });
  });
}
