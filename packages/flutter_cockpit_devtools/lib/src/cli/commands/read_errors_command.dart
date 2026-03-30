import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_latest_task_store.dart';
import '../../application/cockpit_read_errors_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadErrorsFunction = Future<CockpitReadErrorsResult> Function(
  CockpitReadErrorsRequest request,
);

final class ReadErrorsCommand extends Command<int> {
  ReadErrorsCommand({
    CockpitReadErrorsService? service,
    CockpitReadErrorsFunction? read,
    StringSink? stdoutSink,
  })  : _read = read ??
            ((service ??
                    CockpitReadErrorsService(
                      registry: CockpitSessionRegistry(),
                      latestTaskStore: CockpitLatestTaskStore(),
                    ))
                .read),
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser
      ..addFlag('include-latest-task', defaultsTo: true)
      ..addFlag('include-sessions', defaultsTo: true)
      ..addOption('max-errors');
  }

  final CockpitReadErrorsFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-errors';

  @override
  String get description =>
      'Read current runtime errors for a running app, optionally merged with tracked sessions and the latest task bundle.';

  @override
  Future<int> run() async {
    final hasAppReference =
        ((argResults?['app-json'] as String?)?.isNotEmpty ?? false) ||
            ((argResults?['base-url'] as String?)?.isNotEmpty ?? false);
    final result = await _read(
      CockpitReadErrorsRequest(
        appHandlePath: argResults?['app-json'] as String?,
        baseUri: cockpitReadOptionalBaseUri(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        maxErrors: cockpitReadOptionalInt(argResults, 'max-errors') ?? 20,
        includeLatestTask: hasAppReference &&
                !(argResults?.wasParsed('include-latest-task') ?? false)
            ? null
            : argResults?['include-latest-task'] as bool? ?? true,
        includeSessions: hasAppReference &&
                !(argResults?.wasParsed('include-sessions') ?? false)
            ? null
            : argResults?['include-sessions'] as bool? ?? true,
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
