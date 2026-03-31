import '../../application/cockpit_lsp_service.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitLspToolFunction = Future<CockpitLspResult> Function(
  CockpitLspRequest request,
);

final class CockpitLspTool extends CockpitMcpTool {
  CockpitLspTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitLspService? service,
    CockpitLspToolFunction? invoke,
  })  : _rootsTracker = rootsTracker,
        _invoke = invoke ?? (service ?? CockpitLspService()).invoke;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitLspToolFunction _invoke;

  @override
  String get name => 'lsp';

  @override
  String get description =>
      'Run bounded Dart LSP requests with relative paths and 1-based line and column inputs.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: false,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.codeIntelligence,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['command'],
        'properties': <String, Object?>{
          'workspace_root': <String, Object?>{'type': 'string'},
          'command': <String, Object?>{
            'type': 'string',
            'enum': <String>[
              'hover',
              'definition',
              'signature_help',
              'document_symbols',
              'workspace_symbols',
            ],
          },
          'path': <String, Object?>{'type': 'string'},
          'line': <String, Object?>{'type': 'integer'},
          'column': <String, Object?>{'type': 'integer'},
          'query': <String, Object?>{'type': 'string'},
          'max_results': <String, Object?>{'type': 'integer'},
          'max_chars': <String, Object?>{'type': 'integer'},
          'timeout_seconds': <String, Object?>{'type': 'integer'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final workspaceRoot = cockpitResolveWorkspaceRootFromArguments(
        arguments,
        _rootsTracker,
      );
      final result = await _invoke(
        CockpitLspRequest(
          workspaceRoot: workspaceRoot,
          command: _commandFromArgument(
            cockpitReadRequiredString(arguments, 'command'),
          ),
          path: cockpitReadOptionalString(arguments, 'path'),
          line: cockpitReadOptionalInt(arguments, 'line'),
          column: cockpitReadOptionalInt(arguments, 'column'),
          query: cockpitReadOptionalString(arguments, 'query'),
          allowedRoots: cockpitAllowedWorkspaceRootPaths(_rootsTracker),
          maxResults: cockpitReadOptionalInt(arguments, 'max_results') ?? 20,
          maxChars: cockpitReadOptionalInt(arguments, 'max_chars') ?? 1600,
          timeout: Duration(
            seconds: cockpitReadOptionalInt(arguments, 'timeout_seconds') ?? 20,
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'LSP request completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }

  CockpitLspCommand _commandFromArgument(String value) {
    return switch (value) {
      'hover' => CockpitLspCommand.hover,
      'definition' => CockpitLspCommand.definition,
      'signature_help' => CockpitLspCommand.signatureHelp,
      'document_symbols' => CockpitLspCommand.documentSymbols,
      'workspace_symbols' => CockpitLspCommand.workspaceSymbols,
      _ => throw CockpitMcpError.invalidArguments(
          'command must be one of hover, definition, signature_help, document_symbols, or workspace_symbols.',
          details: const <String, Object?>{'argument': 'command'},
        ),
    };
  }
}
