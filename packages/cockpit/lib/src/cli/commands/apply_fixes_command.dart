import 'dart:io';

import '../../application/cockpit_apply_workspace_fixes_service.dart';
import '../../application/cockpit_workspace_command_result.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitApplyFixesFunction =
    Future<CockpitWorkspaceCommandResult> Function(
      CockpitApplyWorkspaceFixesRequest request,
    );

final class ApplyFixesCommand extends CockpitCliCommand {
  ApplyFixesCommand({
    CockpitApplyWorkspaceFixesService? service,
    CockpitApplyFixesFunction? apply,
    StringSink? stdoutSink,
  }) : _apply = apply ?? (service ?? CockpitApplyWorkspaceFixesService()).apply,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser.addOption(
      'timeout-seconds',
      defaultsTo: '180',
      help: 'Time budget for dart fix --apply.',
    );
  }

  final CockpitApplyFixesFunction _apply;
  final StringSink _stdoutSink;

  @override
  String get name => 'apply-fixes';

  @override
  String get description =>
      'Run dart fix --apply for the current or chosen workspace root.';

  @override
  String get summary => 'Apply bounded automatic fixes.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use after diagnostics show supported automatic fixes and you want one bounded cleanup pass.';

  @override
  String get helpNeeds => 'workspace-root defaults to the current directory.';

  @override
  String get helpExample => 'cockpit apply-fixes --workspace-root .';

  @override
  String get helpWrites =>
      'The raw workspace command result with stdout, stderr, exit code, and success.';

  @override
  Future<int> run() async {
    final result = await _apply(
      CockpitApplyWorkspaceFixesRequest(
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
