import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_list_targets_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/list_targets_command.dart';
import 'package:test/test.dart';

void main() {
  test('list-targets writes launchable id and normalized platform', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
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
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    final targets = decoded['targets'] as List<Object?>;
    final target = targets.single as Map<String, Object?>;
    expect(target['id'], 'chrome');
    expect(target['platform'], 'web');
    expect(target['platformType'], 'web-javascript');
  });
}
