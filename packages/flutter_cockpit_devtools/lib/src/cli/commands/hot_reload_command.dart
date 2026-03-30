import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_hot_reload_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitHotReloadFunction = Future<CockpitHotReloadResult> Function(
  CockpitHotReloadRequest request,
);

final class HotReloadCommand extends Command<int> {
  HotReloadCommand({
    CockpitHotReloadService? service,
    CockpitHotReloadFunction? reload,
    StringSink? stdoutSink,
  })  : _reload = reload ?? (service ?? CockpitHotReloadService()).reload,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('app-json')
      ..addOption('output-json');
  }

  final CockpitHotReloadFunction _reload;
  final StringSink _stdoutSink;

  @override
  String get name => 'hot-reload';

  @override
  String get description => 'Trigger hot reload for a development app.';

  @override
  Future<int> run() async {
    final appJson = argResults?['app-json'] as String?;
    if (appJson == null || appJson.isEmpty) {
      throw UsageException('--app-json is required.', usage);
    }
    final result =
        await _reload(CockpitHotReloadRequest(appHandlePath: appJson));
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
