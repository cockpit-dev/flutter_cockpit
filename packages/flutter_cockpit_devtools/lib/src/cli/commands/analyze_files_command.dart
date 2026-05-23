import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_analyze_files_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitAnalyzeFilesFunction = Future<CockpitAnalyzeFilesResult>
    Function(
  CockpitAnalyzeFilesRequest request,
);

final class AnalyzeFilesCommand extends CockpitCliCommand {
  AnalyzeFilesCommand({
    CockpitAnalyzeFilesService? service,
    CockpitAnalyzeFilesFunction? analyze,
    StringSink? stdoutSink,
  })  : _analyze = analyze ?? (service ?? CockpitAnalyzeFilesService()).analyze,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser
      ..addMultiOption(
        'path',
        help:
            'Relative or absolute file or directory to analyze. Repeat as needed.',
      )
      ..addOption(
        'max-diagnostics',
        defaultsTo: '50',
        help: 'Maximum number of diagnostics returned in the payload.',
      )
      ..addOption(
        'max-output-chars',
        defaultsTo: '1600',
        help: 'Maximum preview size returned from analyzer stdout or stderr.',
      )
      ..addOption(
        'timeout-seconds',
        defaultsTo: '120',
        help: 'Time budget for focused analysis.',
      );
  }

  final CockpitAnalyzeFilesFunction _analyze;
  final StringSink _stdoutSink;

  @override
  String get name => 'analyze-files';

  @override
  String get description =>
      'Run analyzer on a bounded set of files or directories and return concise diagnostics.';

  @override
  String get summary => 'Run focused analyzer diagnostics.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use after local code edits when the question is scoped to a few files and workspace-wide analysis would waste tokens.';

  @override
  String get helpNeeds =>
      'At least one --path. workspace-root defaults to the current directory.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools analyze-files --path lib/main.dart --path test/widget_test.dart';

  @override
  String get helpWrites =>
      'A bounded diagnostics payload with severity counts and truncated analyzer previews.';

  @override
  Future<int> run() async {
    final paths = cockpitReadMultiStringOption(argResults, 'path');
    if (paths.isEmpty) {
      throw UsageException('--path is required at least once.', usage);
    }
    final result = await _analyze(
      CockpitAnalyzeFilesRequest(
        workspaceRoot: cockpitReadWorkspaceRoot(argResults),
        paths: paths,
        maxDiagnostics: cockpitReadRequiredPositiveIntOption(
          argResults,
          'max-diagnostics',
          usage,
        ),
        maxOutputChars: cockpitReadRequiredPositiveIntOption(
          argResults,
          'max-output-chars',
          usage,
        ),
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
