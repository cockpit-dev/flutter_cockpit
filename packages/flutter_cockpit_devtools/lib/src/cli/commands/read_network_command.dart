import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_read_network_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitReadNetworkFunction = Future<CockpitReadNetworkResult> Function(
  CockpitReadNetworkRequest request,
);

final class ReadNetworkCommand extends CockpitCliCommand {
  ReadNetworkCommand({
    CockpitReadNetworkService? service,
    CockpitReadNetworkFunction? read,
    StringSink? stdoutSink,
  })  : _read = read ??
            (service ??
                    CockpitReadNetworkService(
                        registry: CockpitSessionRegistry()))
                .read,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddAppArgs(argParser);
    argParser
      ..addOption(
        'max-entries',
        help:
            'Maximum number of matching request entries to retain for failures or optional entries.',
      )
      ..addOption(
        'max-endpoints',
        help:
            'Maximum number of endpoint summaries to include. Lower this to save tokens.',
      )
      ..addFlag(
        'include-entries',
        defaultsTo: false,
        help:
            'Include bounded matching request entries in addition to summary and recent failures.',
      )
      ..addOption(
        'method',
        help: 'Optional HTTP method filter such as GET or POST.',
      )
      ..addOption(
        'uri-contains',
        help: 'Optional URI substring filter.',
      )
      ..addOption(
        'status-code-at-least',
        help: 'Optional minimum status code filter.',
      )
      ..addFlag(
        'only-failures',
        defaultsTo: false,
        help: 'Limit the network view to failing requests only.',
      );
  }

  final CockpitReadNetworkFunction _read;
  final StringSink _stdoutSink;

  @override
  String get name => 'read-network';

  @override
  String get description =>
      'Read bounded app-centric network activity with endpoint summaries and recent failures.';

  @override
  String get summary => 'Read recent network activity.';

  @override
  String get category => CockpitCliCategory.evidence;

  @override
  String get helpWhen =>
      'Check whether a request fired, which endpoints were hit, or which network failures happened after an action.';

  @override
  String get helpNeeds =>
      'An app reference. Usually run the triggering action, then wait-idle, then start without --include-entries and raise detail only when the summary is not enough.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools read-network --app-json /tmp/app.json --uri-contains /api --only-failures';

  @override
  String get helpWrites =>
      'A bounded network view with summary, endpoint summaries, recent failures, and optional matching entries.';

  @override
  Future<int> run() async {
    cockpitRequireAppReference(argResults, usage);
    final result = await _read(
      CockpitReadNetworkRequest(
        appHandlePath: argResults?['app-json'] as String?,
        baseUri: cockpitReadOptionalBaseUri(argResults),
        androidDeviceId: argResults?['android-device-id'] as String?,
        maxEntries: cockpitReadOptionalInt(argResults, 'max-entries') ?? 8,
        maxEndpointSummaries:
            cockpitReadOptionalInt(argResults, 'max-endpoints') ?? 8,
        includeEntries: argResults?['include-entries'] as bool? ?? false,
        method: argResults?['method'] as String?,
        uriContains: argResults?['uri-contains'] as String?,
        statusCodeAtLeast:
            cockpitReadOptionalInt(argResults, 'status-code-at-least'),
        onlyFailures: argResults?['only-failures'] as bool? ?? false,
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
