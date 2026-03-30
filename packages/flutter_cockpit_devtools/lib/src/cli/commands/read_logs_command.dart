import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_read_logs_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadLogsFunction = Future<CockpitReadLogsResult> Function(
  CockpitReadLogsRequest request,
);

final class ReadLogsCommand extends Command<int> {
  ReadLogsCommand({
    CockpitReadLogsService? service,
    CockpitReadLogsFunction? read,
    StringSink? stdoutSink,
  })  : _read = read ??
            (service ??
                    CockpitReadLogsService(registry: CockpitSessionRegistry()))
                .read,
        _stdoutSink = stdoutSink ?? stdout {
    argParser
      ..addOption('app-json')
      ..addOption('max-lines')
      ..addOption('output-json');
  }

  final CockpitReadLogsFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-logs';

  @override
  String get description => 'Read the latest app-centric logs.';

  @override
  Future<int> run() async {
    final appJson = argResults?['app-json'] as String?;
    if (appJson == null || appJson.isEmpty) {
      throw UsageException('--app-json is required.', usage);
    }
    final result = await _read(
      CockpitReadLogsRequest(
        appHandlePath: appJson,
        maxLines: cockpitReadOptionalInt(argResults, 'max-lines') ?? 200,
      ),
    );
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
