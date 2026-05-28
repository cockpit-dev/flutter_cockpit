import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_list_targets_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitListTargetsFunction =
    Future<CockpitListTargetsResult> Function(Duration timeout);

final class ListTargetsCommand extends CockpitCliCommand {
  ListTargetsCommand({
    CockpitListTargetsService? service,
    CockpitListTargetsFunction? listTargets,
    StringSink? stdoutSink,
  }) : _listTargets =
           listTargets ??
           ((timeout) =>
               (service ?? CockpitListTargetsService()).list(timeout: timeout)),
       _stdoutSink = stdoutSink ?? stdout {
    argParser.addOption(
      'timeout-seconds',
      help: 'Time budget for flutter devices discovery before it is aborted.',
      defaultsTo: '60',
    );
  }

  final CockpitListTargetsFunction _listTargets;
  final StringSink _stdoutSink;

  @override
  String get name => 'list-targets';

  @override
  String get description =>
      'List reachable Flutter devices that can be used as launch targets.';

  @override
  String get summary => 'Show launchable Flutter targets.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Start here when you do not yet know which device or platform is available for launch.';

  @override
  String get helpNeeds =>
      'No required inputs. Default stdout is AI-readable; add --stdout-format json when a quick device choice should use jq.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools list-targets --stdout-format json | jq \'.targets[] | {id,platform}\'';

  @override
  String get helpWrites =>
      'A JSON list of reachable Flutter devices and platforms.';

  @override
  Future<int> run() async {
    final timeoutSeconds =
        cockpitReadOptionalPositiveInt(argResults, 'timeout-seconds', usage) ??
        60;
    final result = await _listTargets(Duration(seconds: timeoutSeconds));
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
