import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_stop_app_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStopAppFunction = Future<CockpitStopAppResult> Function(
  CockpitStopAppRequest request,
);

final class StopAppCommand extends CockpitCliCommand {
  StopAppCommand({
    CockpitStopAppService? service,
    CockpitStopAppFunction? stop,
    StringSink? stdoutSink,
  })  : _stop = stop ?? (service ?? CockpitStopAppService()).stop,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption(
        'app-json',
        help: 'App handle JSON emitted by launch-app.',
      )
      ..addOption(
        'output-json',
        help:
            'Optional file path where the stopped app result JSON should be written.',
      );
  }

  final CockpitStopAppFunction _stop;
  final StringSink _stdoutSink;

  @override
  String get name => 'stop-app';

  @override
  String get description => 'Stop a launched app and emit the final app state.';

  @override
  String get summary => 'Stop the launched app and clean up.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'End an app-first loop and release the running app, recorder, and attach processes.';

  @override
  String get helpNeeds => 'An app handle emitted by launch-app.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools stop-app --app-json /tmp/app.json';

  @override
  String get helpWrites =>
      'The final app state and shutdown status after cleanup completes.';

  @override
  Future<int> run() async {
    final appJson = argResults?['app-json'] as String?;
    if (appJson == null || appJson.isEmpty) {
      throw UsageException('--app-json is required.', usage);
    }
    final result = await _stop(CockpitStopAppRequest(appHandlePath: appJson));
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
