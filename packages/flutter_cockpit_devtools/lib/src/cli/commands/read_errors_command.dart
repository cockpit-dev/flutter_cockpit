import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_latest_task_store.dart';
import '../../application/cockpit_read_errors_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadErrorsFunction = Future<CockpitReadErrorsResult> Function(
  CockpitReadErrorsRequest request,
);

final class ReadErrorsCommand extends CockpitCliCommand {
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
      ..addFlag(
        'include-latest-task',
        defaultsTo: true,
        help:
            'Merge runtime errors from the latest completed task bundle when available.',
      )
      ..addFlag(
        'include-sessions',
        defaultsTo: true,
        help:
            'Merge runtime errors tracked from known sessions when no direct app signal exists.',
      )
      ..addOption(
        'max-errors',
        help: 'Maximum number of errors to include in the result.',
      );
  }

  final CockpitReadErrorsFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-errors';

  @override
  String get description =>
      'Read current runtime errors for a running app, optionally merged with tracked sessions and the latest task bundle.';

  @override
  String get summary => 'Read current runtime errors.';

  @override
  String get category => CockpitCliCategory.evidence;

  @override
  String get helpWhen =>
      'Check whether the current app or the latest tracked run produced runtime failures.';

  @override
  String get helpNeeds =>
      'An app reference for app-scoped errors, or no app reference when you want the latest tracked errors across sessions.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools read-errors --app-json /tmp/app.json --max-errors 10 --stdout-format json | jq \'{hasErrors,routeName,errorMessages: [.errors[].message]}\'';

  @override
  String get helpWrites =>
      'A merged error view with app, session, and latest-task context when requested.';

  @override
  Future<int> run() async {
    final hasAppReference =
        ((cockpitResolveAppHandlePath(argResults))?.isNotEmpty ?? false) ||
            ((argResults?['base-url'] as String?)?.isNotEmpty ?? false);
    final result = await _read(
      CockpitReadErrorsRequest(
        appHandlePath: cockpitResolveAppHandlePath(argResults),
        baseUri: cockpitReadOptionalBaseUri(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        maxErrors:
            cockpitReadOptionalPositiveInt(argResults, 'max-errors', usage) ??
                20,
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
