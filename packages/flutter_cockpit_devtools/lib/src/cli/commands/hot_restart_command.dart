import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_hot_restart_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitHotRestartFunction = Future<CockpitHotRestartResult> Function(
  CockpitHotRestartRequest request,
);

final class HotRestartCommand extends Command<int> {
  HotRestartCommand({
    CockpitHotRestartService? service,
    CockpitHotRestartFunction? restart,
    StringSink? stdoutSink,
  })  : _restart = restart ?? (service ?? CockpitHotRestartService()).restart,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('app-json')
      ..addOption('output-json');
  }

  final CockpitHotRestartFunction _restart;
  final StringSink _stdoutSink;

  @override
  String get name => 'hot-restart';

  @override
  String get description => 'Trigger hot restart for a development app.';

  @override
  Future<int> run() async {
    final appJson = argResults?['app-json'] as String?;
    if (appJson == null || appJson.isEmpty) {
      throw UsageException('--app-json is required.', usage);
    }
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
