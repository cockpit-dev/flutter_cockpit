import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_read_logs_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadLogsFunction = Future<CockpitReadLogsResult> Function(
  CockpitReadLogsRequest request,
);

final class ReadLogsCommand extends CockpitCliCommand {
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
      ..addOption(
        'app-json',
        help: 'App handle JSON emitted by launch-app.',
      )
      ..addOption(
        'max-lines',
        help: 'Maximum number of recent log lines to include in the result.',
      )
      ..addOption(
        'output-json',
        help:
            'Optional file path where the log payload JSON should be written.',
      );
  }

  final CockpitReadLogsFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-logs';

  @override
  String get description => 'Read the latest app-centric logs.';

  @override
  String get summary => 'Read latest app logs.';

  @override
  String get category => CockpitCliCategory.evidence;

  @override
  String get helpWhen =>
      'Check the newest app logs after a failure, warning, or suspicious transition.';

  @override
  String get helpNeeds =>
      'An app handle. max-lines defaults to 200 and can be reduced to save tokens.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools read-logs --app-json /tmp/app.json --max-lines 40';

  @override
  String get helpWrites =>
      'A log payload scoped to the current app. available=true with zero lines is a valid result.';

  @override
  Future<int> run() async {
    final appJson = cockpitRequireResolvedAppHandlePath(argResults, usage);
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
