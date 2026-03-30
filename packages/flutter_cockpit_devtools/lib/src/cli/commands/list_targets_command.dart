import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_list_targets_service.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_interactive_cli_support.dart';

typedef CockpitListTargetsFunction = Future<CockpitListTargetsResult>
    Function();

final class ListTargetsCommand extends Command<int> {
  ListTargetsCommand({
    CockpitListTargetsService? service,
    CockpitListTargetsFunction? listTargets,
    StringSink? stdoutSink,
  })  : _listTargets =
            listTargets ?? (service ?? CockpitListTargetsService()).list,
        _stdoutSink = stdoutSink ?? stdout {
    argParser.addOption('output-json');
  }

  final CockpitListTargetsFunction _listTargets;
  final StringSink _stdoutSink;

  @override
  String get name => 'list-targets';

  @override
  String get description => 'List available Flutter launch targets.';

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
