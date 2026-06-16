import 'dart:io';

import '../../application/cockpit_run_workspace_tests_service.dart';
import '../../application/cockpit_workspace_command_result.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitRunTestsFunction =
    Future<CockpitWorkspaceCommandResult> Function(
      CockpitRunWorkspaceTestsRequest request,
    );

final class RunTestsCommand extends CockpitCliCommand {
  RunTestsCommand({
    CockpitRunWorkspaceTestsService? service,
    CockpitRunTestsFunction? run,
    StringSink? stdoutSink,
  }) : _run = run ?? (service ?? CockpitRunWorkspaceTestsService()).run,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser.addOption(
      'timeout-seconds',
      defaultsTo: '300',
      help: 'Time budget for workspace tests.',
    );
  }

  final CockpitRunTestsFunction _run;
  final StringSink _stdoutSink;

  @override
  String get name => 'run-tests';

  @override
  String get description =>
      'Run unit or widget tests for the current or chosen workspace root.';

  @override
  String get summary => 'Run workspace tests.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use after a code change when AI needs one executable pass that validates the workspace instead of guessing from source.';

  @override
  String get helpNeeds => 'workspace-root defaults to the current directory.';

  @override
  String get helpExample => 'cockpit run-tests --workspace-root .';

  @override
  String get helpWrites =>
      'The raw workspace command result with stdout, stderr, exit code, and success.';

  @override
  Future<int> run() async {
    final result = await _run(
      CockpitRunWorkspaceTestsRequest(
        workspaceRoot: cockpitReadWorkspaceRoot(argResults),
        timeout: Duration(
          seconds: cockpitReadRequiredPositiveIntOption(
            argResults,
            'timeout-seconds',
            usage,
          ),
        ),
      ),
    );
    await cockpitWriteWorkspacePayload(
      payload: result.toJson(),
      argResults: argResults,
      stdoutSink: _stdoutSink,
    );
    return cockpitSuccessExitCode;
  }
}
