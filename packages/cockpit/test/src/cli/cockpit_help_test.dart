import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/cli/commands/hot_reload_command.dart';
import 'package:cockpit/src/cli/commands/hot_restart_command.dart';
import 'package:cockpit/src/cli/commands/inspect_ui_command.dart';
import 'package:cockpit/src/cli/commands/inspect_surface_command.dart';
import 'package:cockpit/src/cli/commands/capture_screenshot_command.dart';
import 'package:cockpit/src/cli/commands/collect_development_probe_command.dart';
import 'package:cockpit/src/cli/commands/collect_remote_snapshot_command.dart';
import 'package:cockpit/src/cli/commands/compare_development_probe_command.dart';
import 'package:cockpit/src/cli/commands/execute_remote_command_batch_command.dart';
import 'package:cockpit/src/cli/commands/execute_remote_command_command.dart';
import 'package:cockpit/src/cli/commands/launch_app_command.dart';
import 'package:cockpit/src/cli/commands/launch_development_session_command.dart';
import 'package:cockpit/src/cli/commands/launch_remote_session_command.dart';
import 'package:cockpit/src/cli/commands/launch_target_command.dart';
import 'package:cockpit/src/cli/commands/lsp_command.dart';
import 'package:cockpit/src/cli/commands/list_targets_command.dart';
import 'package:cockpit/src/cli/commands/pub_command.dart';
import 'package:cockpit/src/cli/commands/pub_dev_search_command.dart';
import 'package:cockpit/src/cli/commands/query_development_session_command.dart';
import 'package:cockpit/src/cli/commands/query_remote_session_command.dart';
import 'package:cockpit/src/cli/commands/read_app_command.dart';
import 'package:cockpit/src/cli/commands/read_remote_snapshot_command.dart';
import 'package:cockpit/src/cli/commands/read_remote_status_command.dart';
import 'package:cockpit/src/cli/commands/read_system_capabilities_command.dart';
import 'package:cockpit/src/cli/commands/read_target_command.dart';
import 'package:cockpit/src/cli/commands/read_errors_command.dart';
import 'package:cockpit/src/cli/commands/read_logs_command.dart';
import 'package:cockpit/src/cli/commands/read_network_command.dart';
import 'package:cockpit/src/cli/commands/read_package_uris_command.dart';
import 'package:cockpit/src/cli/commands/read_task_bundle_summary_command.dart';
import 'package:cockpit/src/cli/commands/reload_development_session_command.dart';
import 'package:cockpit/src/cli/commands/run_batch_command.dart';
import 'package:cockpit/src/cli/commands/run_command_command.dart';
import 'package:cockpit/src/cli/commands/run_remote_control_script_command.dart';
import 'package:cockpit/src/cli/commands/run_script_command.dart';
import 'package:cockpit/src/cli/commands/run_shell_command.dart';
import 'package:cockpit/src/cli/commands/run_system_action_command.dart';
import 'package:cockpit/src/cli/commands/run_task_command.dart';
import 'package:cockpit/src/cli/commands/run_tests_command.dart';
import 'package:cockpit/src/cli/commands/serve_mcp_command.dart';
import 'package:cockpit/src/cli/commands/start_recording_command.dart';
import 'package:cockpit/src/cli/commands/start_remote_recording_command.dart';
import 'package:cockpit/src/cli/commands/stop_app_command.dart';
import 'package:cockpit/src/cli/commands/stop_development_session_command.dart';
import 'package:cockpit/src/cli/commands/stop_recording_command.dart';
import 'package:cockpit/src/cli/commands/stop_remote_recording_command.dart';
import 'package:cockpit/src/cli/commands/validate_task_command.dart';
import 'package:cockpit/src/cli/commands/wait_idle_command.dart';
import 'package:cockpit/src/cli/commands/wait_remote_ui_idle_command.dart';
import 'package:cockpit/src/cli/commands/analyze_files_command.dart';
import 'package:cockpit/src/cli/commands/analyze_workspace_command.dart';
import 'package:cockpit/src/cli/commands/apply_fixes_command.dart';
import 'package:cockpit/src/cli/commands/create_project_command.dart';
import 'package:cockpit/src/cli/commands/format_workspace_command.dart';
import 'package:cockpit/src/cli/commands/grep_package_uris_command.dart';
import 'package:test/test.dart';

void main() {
  test('root help explains the shortest AI-first loop', () async {
    final help = await _captureHelp(const <String>['--help']);

    expect(help, contains('Fast loop (default app-first):'));
    expect(help, contains('Workspace'));
    expect(help, contains('launch-app'));
    expect(help, contains('launch-target'));
    expect(help, contains('read-target'));
    expect(help, contains('inspect-surface'));
    expect(help, contains('run-shell'));
    expect(help, contains('analyze-files'));
    expect(help, contains('lsp'));
    expect(help, contains('pub'));
    expect(help, contains('grep-package-uris'));
    expect(help, contains('run-command'));
    expect(help, contains('capture-screenshot'));
    expect(help, contains('hot-reload'));
    expect(help, contains('read-errors --max-errors 10'));
    expect(help, contains('Use stop-app for cleanup or recovery only'));
    expect(
      help,
      isNot(
        contains('  run-command --command-file <command.json>\n  stop-app'),
      ),
    );
    expect(help, contains('read-network'));
    expect(help, contains('run-task'));
    expect(help, contains('--output-format json'));
    expect(help, contains('If a flag or JSON shape is unclear'));
    expect(help, contains('--device-id <id for android|ios|web>'));
    expect(
      help,
      contains(
        '--target-json /tmp/target.json --output /tmp/launch_target.json --output-format json',
      ),
    );
    expect(help, contains('latest_app.json'));
    expect(help, contains("jq '.app' /tmp/launch_target.json > /tmp/app.json"));
    expect(help, contains('current directory'));
  });

  test('help coverage matches the registered top-level commands', () {
    final registered = CockpitCommandRunner().commands.keys
        .where((name) => name != 'help')
        .toList(growable: false);
    final covered = _topLevelCommands
        .map<String>((command) => command.name as String)
        .toList(growable: false);

    expect(covered, registered);
    expect(covered.toSet(), hasLength(covered.length));

    final rootUsage = CockpitCommandRunner().usage;
    for (final commandName in registered) {
      expect(
        RegExp(
          '(^|\\n)  ${RegExp.escape(commandName)}\\s+',
        ).hasMatch(rootUsage),
        isTrue,
        reason: '$commandName should be visible from root help.',
      );
    }
  });

  test('launch-app help explains required inputs and emitted handle', () {
    final usage = _helpForCommand(LaunchAppCommand());

    expect(usage, contains('Flutter project directory to launch.'));
    expect(usage, contains('Optional Dart entrypoint.'));
    expect(usage, contains('cockpit/main.dart first, then lib/main.dart'));
    expect(usage, contains('android, ios, macos, windows, linux, or web'));
    expect(usage, contains('When:'));
    expect(usage, contains('App-first is the lowest-friction path'));
    expect(usage, contains('project-dir defaults to the current directory'));
    expect(usage, contains('platform defaults to the host desktop platform'));
    expect(usage, contains('Pass --platform and --device-id'));
    expect(usage, contains('--flavor'));
    expect(usage, contains('Web currently launches through development mode'));
    expect(usage, contains('Writes:'));
    expect(usage, contains('app.json'));
    expect(usage, contains('returns after the app is ready'));
    expect(usage, contains('development supervisor keeps logs'));
    expect(usage, contains('reload'));
    expect(usage, contains('stop control alive in the background'));
    expect(usage, contains('Example:'));
  });

  test('target-first command help explains the normalized target loop', () {
    expect(_helpForCommand(LaunchTargetCommand()), contains('When:'));
    expect(_helpForCommand(LaunchTargetCommand()), contains('embedded .app'));
    expect(_helpForCommand(LaunchTargetCommand()), contains('--flavor'));
    expect(
      _helpForCommand(LaunchTargetCommand()),
      contains('Web target-first loops also use development mode'),
    );
    expect(
      _helpForCommand(LaunchTargetCommand()),
      contains('--output /tmp/launch_target.json --output-format json'),
    );
    expect(
      _helpForCommand(LaunchTargetCommand()),
      contains('--platform web --device-id chrome --output'),
    );
    expect(_helpForCommand(ReadTargetCommand()), contains('Example:'));
    expect(_helpForCommand(InspectSurfaceCommand()), contains('Writes:'));
    expect(_helpForCommand(RunShellCommand()), contains('target-json'));
    expect(_helpForCommand(RunShellCommand()), isNot(contains('web]')));
  });

  test('list-targets help describes device discovery and timeout control', () {
    final usage = _helpForCommand(ListTargetsCommand());

    expect(usage, contains('reachable Flutter devices and platforms'));
    expect(usage, contains('timeout-seconds'));
    expect(usage, contains('flutter devices discovery'));
  });

  test('run-command help documents command shape and profiles', () {
    final usage = _helpForCommand(RunCommandCommand());

    expect(usage, contains('command.json'));
    expect(usage, contains('"commandId"'));
    expect(usage, contains('"commandType"'));
    expect(usage, contains('safe first commandType values'));
    expect(usage, contains('captureScreenshot'));
    expect(usage, contains('minimal=core only'));
    expect(usage, contains('compare-against-snapshot-ref'));
    expect(
      usage,
      contains(
        'text, semanticId, tooltip, type, ancestor, index, or fallbacks',
      ),
    );
    expect(
      usage,
      contains('use key only when the app already exposes a stable key'),
    );
  });

  test('run-batch help exposes whole-batch recording for evidence capture', () {
    final usage = _helpForCommand(RunBatchCommand());

    expect(usage, contains('--recording-json or --recording-file'));
    expect(usage, contains('open -> edit -> save style flows'));
    expect(usage, contains('optional recording metadata'));
  });

  test('development session help exposes app handle recording path', () {
    final usage = _helpForCommand(LaunchDevelopmentSessionCommand());

    expect(usage, contains('--app-json'));
    expect(
      usage,
      contains('recording commands stay in the flutter_cockpit flow'),
    );
    expect(usage, contains('run-batch --recording-json'));
    expect(usage, contains('start-recording'));
    expect(usage, contains('stop-recording'));
  });

  test('delivery task help defaults to AI-readable output', () {
    final runTaskUsage = _helpForCommand(RunTaskCommand());
    final validateTaskUsage = _helpForCommand(ValidateTaskCommand());
    final readBundleUsage = _helpForCommand(ReadTaskBundleSummaryCommand());
    final runScriptUsage = _helpForCommand(RunScriptCommand());
    final runRemoteScriptUsage = _helpForCommand(
      RunRemoteControlScriptCommand(),
    );

    expect(runTaskUsage, contains('cockpit run-task --config'));
    expect(
      runTaskUsage,
      isNot(
        contains('run-task --config /tmp/run_task.yaml --stdout-format json'),
      ),
    );
    expect(
      runTaskUsage,
      contains('compact AI-readable issues and bundle sections'),
    );
    expect(validateTaskUsage, contains('cockpit validate-task --config'));
    expect(
      validateTaskUsage,
      isNot(
        contains(
          'validate-task --config /tmp/validate_task.yaml --stdout-format json',
        ),
      ),
    );
    expect(
      validateTaskUsage,
      contains('compact AI-readable issues and bundle sections'),
    );
    expect(
      readBundleUsage,
      contains('cockpit read-task-bundle-summary --bundle-dir'),
    );
    expect(readBundleUsage, contains('compact AI-readable summary by default'));
    expect(
      readBundleUsage,
      contains('lower camel case JSON with --stdout-format json'),
    );
    expect(runScriptUsage, contains('exits non-zero'));
    expect(runRemoteScriptUsage, contains('exits non-zero'));
  });

  test('app-scoped command help explains default latest_app.json reuse', () {
    final usages = <String>[
      _helpForCommand(ReadAppCommand()),
      _helpForCommand(RunCommandCommand()),
      _helpForCommand(RunBatchCommand()),
      _helpForCommand(StartRecordingCommand()),
      _helpForCommand(StopRecordingCommand()),
      _helpForCommand(ReadLogsCommand()),
      _helpForCommand(HotReloadCommand()),
      _helpForCommand(HotRestartCommand()),
      _helpForCommand(StopAppCommand()),
    ];

    for (final usage in usages) {
      expect(usage, contains('.dart_tool/flutter_cockpit/latest_app.json'));
    }
  });

  test('launch-app help describes explicit app-json as a replacement path', () {
    final usage = _helpForCommand(LaunchAppCommand());

    expect(usage, contains('If --app-json is omitted'));
    expect(
      usage,
      contains(
        'When --app-json is provided, that explicit path is written instead.',
      ),
    );
  });

  test(
    'recording help explains when to record and how artifacts are finalized',
    () {
      final startUsage = _helpForCommand(StartRecordingCommand());
      final stopUsage = _helpForCommand(StopRecordingCommand());

      expect(
        startUsage,
        contains(
          'Prefer a screenshot when one still state already answers the question',
        ),
      );
      expect(
        startUsage,
        contains(
          'Omit --recording-json for the default repro development recording',
        ),
      );
      expect(startUsage, contains('Default recording = repro auto mode'));
      expect(startUsage, contains('cockpit start-recording'));
      expect(startUsage, contains('stop-recording to finalize the artifact'));
      expect(stopUsage, contains('artifact references'));
    },
  );

  test(
    'system control help distinguishes macOS app id from Windows/Linux process id targets',
    () {
      final readUsage = _helpForCommand(ReadSystemCapabilitiesCommand());
      final runUsage = _helpForCommand(RunSystemActionCommand());

      for (final usage in <String>[readUsage, runUsage]) {
        expect(
          usage,
          contains('required for macOS host screenshots and recordings'),
        );
        expect(usage, contains('Windows/Linux process id for window-scoped'));
      }
    },
  );

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
  LaunchTargetCommand(),
  LaunchRemoteSessionCommand(),
  QueryRemoteSessionCommand(),
  ReadRemoteStatusCommand(),
  ReadRemoteSnapshotCommand(),
  CollectRemoteSnapshotCommand(),
  ReadSystemCapabilitiesCommand(),
  ExecuteRemoteCommandCommand(),
  ExecuteRemoteCommandBatchCommand(),
  WaitRemoteUiIdleCommand(),
  ReadAppCommand(),
  ReadTargetCommand(),
  InspectUiCommand(),
  InspectSurfaceCommand(),
  RunCommandCommand(),
  CaptureScreenshotCommand(),
  RunBatchCommand(),
  RunSystemActionCommand(),
  RunShellCommand(),
  HotReloadCommand(),
  HotRestartCommand(),
  StopAppCommand(),
  WaitIdleCommand(),
  PubDevSearchCommand(),
  PubCommand(),
  ReadPackageUrisCommand(),
  GrepPackageUrisCommand(),
  LspCommand(),
  AnalyzeFilesCommand(),
  CreateProjectCommand(),
  AnalyzeWorkspaceCommand(),
  FormatWorkspaceCommand(),
  RunTestsCommand(),
  ApplyFixesCommand(),
  LaunchDevelopmentSessionCommand(),
  QueryDevelopmentSessionCommand(),
  ReloadDevelopmentSessionCommand(),
  CollectDevelopmentProbeCommand(),
  CompareDevelopmentProbeCommand(),
  StopDevelopmentSessionCommand(),
  StartRecordingCommand(),
  StopRecordingCommand(),
  StartRemoteRecordingCommand(),
  StopRemoteRecordingCommand(),
  ReadLogsCommand(),
  ReadNetworkCommand(),
  ReadErrorsCommand(),
  ReadTaskBundleSummaryCommand(),
  RunTaskCommand(),
  ValidateTaskCommand(),
  ServeMcpCommand(),
  RunScriptCommand(),
  RunRemoteControlScriptCommand(),
];

Future<String> _captureHelp(List<String> args) async {
  final buffer = StringBuffer();
  await runZoned(
    () => CockpitCommandRunner().run(args),
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, String line) {
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
  final runner = CommandRunner<int>('cockpit', 'test');
  runner.addCommand(command);
  return runner;
}
