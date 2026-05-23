import 'dart:io';

import '../../application/cockpit_analyze_workspace_service.dart';
import '../../application/cockpit_workspace_command_result.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitAnalyzeWorkspaceFunction =
    Future<CockpitWorkspaceCommandResult> Function(
      CockpitAnalyzeWorkspaceRequest request,
    );

final class AnalyzeWorkspaceCommand extends CockpitCliCommand {
  AnalyzeWorkspaceCommand({
    CockpitAnalyzeWorkspaceService? service,
    CockpitAnalyzeWorkspaceFunction? analyze,
    StringSink? stdoutSink,
  }) : _analyze =
           analyze ?? (service ?? CockpitAnalyzeWorkspaceService()).analyze,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser.addOption(
      'timeout-seconds',
      defaultsTo: '180',
      help: 'Time budget for workspace-wide analysis.',
    );
  }

  final CockpitAnalyzeWorkspaceFunction _analyze;
  final StringSink _stdoutSink;

  @override
  String get name => 'analyze-workspace';

  @override
  String get description =>
      'Run analyzer for the current or chosen Dart or Flutter workspace.';

  @override
  String get summary => 'Run workspace-wide analysis.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use only when the question is workspace-wide or analyze-files no longer captures the failing surface.';

  @override
  String get helpNeeds => 'workspace-root defaults to the current directory.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools analyze-workspace --workspace-root .';

  @override
  String get helpWrites =>
      'The raw workspace command result with stdout, stderr, exit code, and success.';

  @override
  Future<int> run() async {
    final result = await _analyze(
      CockpitAnalyzeWorkspaceRequest(
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
