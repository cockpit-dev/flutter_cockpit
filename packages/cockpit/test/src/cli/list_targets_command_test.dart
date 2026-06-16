import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cockpit/src/application/cockpit_list_targets_service.dart';
import 'package:cockpit/src/cli/commands/list_targets_command.dart';
import 'package:test/test.dart';

void main() {
  test('list-targets defaults to a CI-safe discovery timeout', () async {
    Duration? capturedTimeout;
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        ListTargetsCommand(
          listTargets: (timeout) async {
            capturedTimeout = timeout;
            return const CockpitListTargetsResult(
              targets: <CockpitLaunchTarget>[],
            );
          },
        ),
      );

    await runner.run(const <String>['list-targets']);

    expect(capturedTimeout, const Duration(seconds: 60));
  });

  test('list-targets writes launchable id and normalized platform', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        ListTargetsCommand(
          stdoutSink: output,
          listTargets: (_) async => const CockpitListTargetsResult(
            targets: <CockpitLaunchTarget>[
              CockpitLaunchTarget(
                id: 'chrome',
                name: 'Chrome',
                platform: 'web',
                platformType: 'web-javascript',
                emulator: false,
                ephemeral: false,
                sdk: 'web',
              ),
            ],
          ),
        ),
      );

    final exitCode = await runner.run(const <String>['list-targets']) ?? 0;

    expect(exitCode, 0);
    expect(output.toString(), contains('cockpit.v=1'));
    expect(output.toString(), contains('command=list-targets'));
    final jsonOutput = StringBuffer();
    final jsonRunner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        ListTargetsCommand(
          stdoutSink: jsonOutput,
          listTargets: (_) async => const CockpitListTargetsResult(
            targets: <CockpitLaunchTarget>[
              CockpitLaunchTarget(
                id: 'chrome',
                name: 'Chrome',
                platform: 'web',
                platformType: 'web-javascript',
                emulator: false,
                ephemeral: false,
                sdk: 'web',
              ),
            ],
          ),
        ),
      );

    await jsonRunner.run(const <String>[
      'list-targets',
      '--stdout-format',
      'json',
    ]);
    final decoded = jsonDecode(jsonOutput.toString()) as Map<String, Object?>;
    final targets = decoded['targets'] as List<Object?>;
    final target = targets.single as Map<String, Object?>;
    expect(target['id'], 'chrome');
    expect(target['platform'], 'web');
    expect(target['platformType'], 'web-javascript');
  });

  test('list-targets rejects invalid timeout seconds', () async {
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        ListTargetsCommand(
          listTargets: (_) async =>
              const CockpitListTargetsResult(targets: <CockpitLaunchTarget>[]),
        ),
      );

    await expectLater(
      () => runner.run(const <String>[
        'list-targets',
        '--timeout-seconds',
        'abc',
      ]),
      throwsA(isA<UsageException>()),
    );
  });
}
