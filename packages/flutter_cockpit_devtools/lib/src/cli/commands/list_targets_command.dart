import 'dart:convert';
import 'dart:io';

import '../../application/cockpit_list_targets_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitListTargetsFunction = Future<CockpitListTargetsResult>
    Function();

final class ListTargetsCommand extends CockpitCliCommand {
  ListTargetsCommand({
    CockpitListTargetsService? service,
    CockpitListTargetsFunction? listTargets,
    StringSink? stdoutSink,
  })  : _listTargets =
            listTargets ?? (service ?? CockpitListTargetsService()).list,
        _stdoutSink = stdoutSink ?? stdout {
    argParser.addOption(
      'output-json',
      help: 'Write the target list JSON to a file instead of stdout.',
    );
  }

  final CockpitListTargetsFunction _listTargets;
  final StringSink _stdoutSink;

  @override
  String get name => 'list-targets';

  @override
  String get description =>
      'List launchable Flutter targets from the current workspace.';

  @override
  String get summary => 'Show launchable Flutter targets.';

  @override
  String get category => CockpitCliCategory.coreLoop;

  @override
  String get helpWhen =>
      'Start here when you do not yet know which project, target, or platform to launch.';

  @override
  String get helpNeeds =>
      'No required inputs. Use --output-json when a later step should read the target list as structured data.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools list-targets --output-json /tmp/targets.json';

  @override
  String get helpWrites =>
      'A JSON list of project directories, entrypoints, and detected platforms.';

  @override
  Future<int> run() async {
    final result = await _listTargets();
    await cockpitWriteJsonPayload(
      payload: const JsonEncoder.withIndent('  ').convert(result.toJson()),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
