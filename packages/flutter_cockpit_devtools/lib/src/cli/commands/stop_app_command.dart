import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_stop_app_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitStopAppFunction = Future<CockpitStopAppResult> Function(
  CockpitStopAppRequest request,
);

final class StopAppCommand extends Command<int> {
  StopAppCommand({
    CockpitStopAppService? service,
    CockpitStopAppFunction? stop,
    StringSink? stdoutSink,
  })  : _stop = stop ?? (service ?? CockpitStopAppService()).stop,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('app-json')
      ..addOption('output-json');
  }

  final CockpitStopAppFunction _stop;
  final StringSink _stdoutSink;

  @override
  String get name => 'stop-app';

  @override
  String get description =>
      'Stop a development app and emit the final app state.';

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
