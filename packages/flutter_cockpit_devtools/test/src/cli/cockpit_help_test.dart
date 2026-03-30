import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/hot_reload_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/hot_restart_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/inspect_ui_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/launch_app_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/list_targets_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_app_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_errors_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_logs_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_batch_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_command_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_script_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/run_task_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/serve_mcp_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/start_recording_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/stop_app_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/stop_recording_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/validate_task_command.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/wait_idle_command.dart';
import 'package:test/test.dart';

void main() {
  test('root help explains the shortest AI-first loop', () async {
    final help = await _captureHelp(const <String>['--help']);

    expect(help, contains('Fast loop:'));
    expect(help, contains('launch-app'));
    expect(help, contains('run-command'));
    expect(help, contains('run-task'));
    expect(help, contains('Use --output-json'));
  });

  test('launch-app help explains required inputs and emitted handle', () {
    final usage = _helpForCommand(LaunchAppCommand());

    expect(usage, contains('Flutter project directory to launch.'));
    expect(usage, contains('Optional Dart entrypoint.'));
    expect(usage, contains('cockpit/main.dart first, then lib/main.dart'));
    expect(usage, contains('When:'));
    expect(usage, contains('Writes:'));
    expect(usage, contains('app.json'));
    expect(usage, contains('Example:'));
  });

  test('run-command help documents command shape and profiles', () {
    final usage = _helpForCommand(RunCommandCommand());

    expect(usage, contains('command.json'));
    expect(usage, contains('"command_id"'));
    expect(usage, contains('"command_type"'));
    expect(usage, contains('"parameters"'));
    expect(usage, contains('minimal=core only'));
    expect(usage, contains('compare-against-snapshot-ref'));
  });

  test('every top-level command gives help text for custom options', () {
    for (final command in _topLevelCommands) {
      for (final option in command.argParser.options.entries) {
        if (option.key == 'help') {
          continue;
        }
        final help = option.value.help;
        expect(
          help,
          isNotNull,
          reason: '${command.name} --${option.key} should describe its use.',
        );
        expect(
          help!.trim(),
          isNotEmpty,
          reason: '${command.name} --${option.key} should not be blank.',
        );
      }
    }
  });

  test('every top-level command gives a short usage footer', () {
    for (final command in _topLevelCommands) {
      final usage = _helpForCommand(command);
      expect(
        usage,
        contains('When:'),
        reason: '${command.name} should explain when to use it.',
      );
      expect(
        usage,
        contains('Example:'),
        reason: '${command.name} should show a minimal example.',
      );
      expect(
        usage,
        contains('Writes:'),
        reason: '${command.name} should describe what it emits.',
      );
    }
  });
}

final List<dynamic> _topLevelCommands = <dynamic>[
  ListTargetsCommand(),
  LaunchAppCommand(),
  ReadAppCommand(),
  InspectUiCommand(),
  RunCommandCommand(),
  RunBatchCommand(),
  HotReloadCommand(),
  HotRestartCommand(),
  StopAppCommand(),
  WaitIdleCommand(),
  StartRecordingCommand(),
  StopRecordingCommand(),
  ReadLogsCommand(),
  ReadErrorsCommand(),
  RunTaskCommand(),
  ValidateTaskCommand(),
  ServeMcpCommand(),
  RunScriptCommand(),
];

Future<String> _captureHelp(List<String> args) async {
  final buffer = StringBuffer();
  await runZoned(
    () => CockpitCommandRunner().run(args),
    zoneSpecification: ZoneSpecification(
      print: (_, __, ___, String line) {
        buffer.writeln(line);
      },
    ),
  );
  return buffer.toString();
}

String _helpForCommand(dynamic command) {
  _testRunnerFor(command);
  return command.usage;
}

dynamic _testRunnerFor(dynamic command) {
  final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test');
  runner.addCommand(command);
  return runner;
}
