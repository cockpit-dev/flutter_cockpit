import 'dart:io';

import '../../application/cockpit_format_workspace_service.dart';
import '../../application/cockpit_workspace_command_result.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitFormatWorkspaceFunction =
    Future<CockpitWorkspaceCommandResult> Function(
      CockpitFormatWorkspaceRequest request,
    );

final class FormatWorkspaceCommand extends CockpitCliCommand {
  FormatWorkspaceCommand({
    CockpitFormatWorkspaceService? service,
    CockpitFormatWorkspaceFunction? format,
    StringSink? stdoutSink,
  }) : _format = format ?? (service ?? CockpitFormatWorkspaceService()).format,
       _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser.addOption(
      'timeout-seconds',
      defaultsTo: '90',
      help: 'Time budget for dart format.',
    );
  }

  final CockpitFormatWorkspaceFunction _format;
  final StringSink _stdoutSink;

  @override
  String get name => 'format-workspace';

  @override
  String get description =>
      'Run dart format for the current or chosen workspace root.';

  @override
  String get summary => 'Run workspace formatting.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use after code edits or before delivery when formatting should match what CI or reviewers expect.';

  @override
  String get helpNeeds => 'workspace-root defaults to the current directory.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools format-workspace --workspace-root .';

  @override
  String get helpWrites =>
      'The raw workspace command result with stdout, stderr, exit code, and success.';

  @override
  Future<int> run() async {
    final result = await _format(
      CockpitFormatWorkspaceRequest(
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
