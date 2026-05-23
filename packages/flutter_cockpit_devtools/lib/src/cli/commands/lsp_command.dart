import 'dart:io';

import 'package:args/command_runner.dart';

import '../../application/cockpit_lsp_service.dart';
import '../cockpit_cli_help.dart';
import '../cockpit_command_runner.dart';
import '../cockpit_workspace_cli_support.dart';

typedef CockpitLspFunction = Future<CockpitLspResult> Function(
  CockpitLspRequest request,
);

final class LspCommand extends CockpitCliCommand {
  LspCommand({
    CockpitLspService? service,
    CockpitLspFunction? invoke,
    StringSink? stdoutSink,
  })  : _invoke = invoke ?? (service ?? CockpitLspService()).invoke,
        _stdoutSink = stdoutSink ?? stdout {
    cockpitAddWorkspaceRootOption(argParser);
    argParser
      ..addOption(
        'command',
        allowed: const <String>[
          'hover',
          'definition',
          'signature-help',
          'document-symbols',
          'workspace-symbols',
        ],
        help: 'Bounded LSP request to run.',
      )
      ..addOption(
        'path',
        help: 'Relative or absolute Dart file path for document requests.',
      )
      ..addOption(
        'line',
        help: '1-based line number for position-based requests.',
      )
      ..addOption(
        'column',
        help: '1-based column number for position-based requests.',
      )
      ..addOption(
        'query',
        help: 'Workspace symbol query string.',
      )
      ..addOption(
        'max-results',
        defaultsTo: '20',
        help: 'Maximum number of definitions or symbols to return.',
      )
      ..addOption(
        'max-chars',
        defaultsTo: '1600',
        help: 'Maximum character budget for hover or documentation text.',
      )
      ..addOption(
        'timeout-seconds',
        defaultsTo: '20',
        help: 'Time budget for the LSP request.',
      );
  }

  final CockpitLspFunction _invoke;
  final StringSink _stdoutSink;

  @override
  String get name => 'lsp';

  @override
  String get description =>
      'Run bounded Dart LSP requests with relative paths and 1-based positions.';

  @override
  String get summary => 'Read code intelligence without opening large files.';

  @override
  String get category => CockpitCliCategory.workspace;

  @override
  String get helpWhen =>
      'Use for hover, definition, signature help, or symbol discovery before reading more source than necessary.';

  @override
  String get helpNeeds =>
      'command is required. workspace-root defaults to the current directory. Document requests usually need path plus line and column.';

  @override
  String get helpExample =>
      'flutter_cockpit_devtools lsp --command hover --path lib/main.dart --line 12 --column 8';

  @override
  String get helpWrites =>
      'A bounded LSP result with the shortest useful payload for the selected command.';

  @override
  Future<int> run() async {
    final result = await _invoke(
      CockpitLspRequest(
        workspaceRoot: cockpitReadWorkspaceRoot(argResults),
        command: _commandFromArgument(
          cockpitReadRequiredStringOption(argResults, 'command', usage),
        ),
        path: cockpitReadOptionalStringOption(argResults, 'path'),
        line: cockpitReadOptionalPositiveIntOption(
          argResults,
          'line',
          usage,
        ),
        column: cockpitReadOptionalPositiveIntOption(
          argResults,
          'column',
          usage,
        ),
        query: cockpitReadOptionalStringOption(argResults, 'query'),
        maxResults: cockpitReadRequiredPositiveIntOption(
          argResults,
          'max-results',
          usage,
        ),
        maxChars: cockpitReadRequiredPositiveIntOption(
          argResults,
          'max-chars',
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

  CockpitLspCommand _commandFromArgument(String value) {
    return switch (value) {
      'hover' => CockpitLspCommand.hover,
      'definition' => CockpitLspCommand.definition,
      'signature-help' => CockpitLspCommand.signatureHelp,
      'document-symbols' => CockpitLspCommand.documentSymbols,
      'workspace-symbols' => CockpitLspCommand.workspaceSymbols,
      _ => throw UsageException('Unsupported lsp command: $value', usage),
    };
  }
}
