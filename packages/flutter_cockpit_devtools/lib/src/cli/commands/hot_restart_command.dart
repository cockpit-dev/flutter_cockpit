import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_hot_restart_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitHotRestartFunction = Future<CockpitHotRestartResult> Function(
  CockpitHotRestartRequest request,
);

final class HotRestartCommand extends CockpitCliCommand {
  HotRestartCommand({
    CockpitHotRestartService? service,
    CockpitHotRestartFunction? restart,
    StringSink? stdoutSink,
  })  : _restart = restart ?? (service ?? CockpitHotRestartService()).restart,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'app-json',
        help: 'App handle JSON emitted by launch-app.',
      )
      ..addOption(
        'output-json',
        help:
            'Optional file path where the restart result JSON should be written.',
      );
  }

  final CockpitHotRestartFunction _restart;
  final StringSink _stdoutSink;

  @override
  String get name => 'hot-restart';

  @override
  String get description => 'Trigger hot restart for a development app.';

  @override
  String get summary => 'Restart app state from source.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Use when hot reload is not enough and you need a clean app state from current source.';

  @override
  String get helpNeeds => 'A development app handle from launch-app.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools hot-restart --app-json /tmp/app.json | jq \'{reloadGeneration: .status.reloadGeneration, lastReloadSucceeded: .status.lastReloadSucceeded, lastReloadMode: .status.lastReloadMode}\'';

  @override
  String get helpWrites =>
      'Updated app metadata and restart status for the running development session.';

  @override
  Future<int> run() async {
    final appJson = cockpitRequireResolvedAppHandlePath(argResults, usage);
    final result =
        await _restart(CockpitHotRestartRequest(appHandlePath: appJson));
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
