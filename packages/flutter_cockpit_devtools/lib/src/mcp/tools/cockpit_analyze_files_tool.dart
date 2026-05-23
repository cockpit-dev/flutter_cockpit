import '../../application/cockpit_analyze_files_service.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitAnalyzeFilesToolFunction = Future<CockpitAnalyzeFilesResult>
    Function(
  CockpitAnalyzeFilesRequest request,
);

final class CockpitAnalyzeFilesTool extends CockpitMcpTool {
  CockpitAnalyzeFilesTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitAnalyzeFilesService? service,
    CockpitAnalyzeFilesToolFunction? analyze,
  })  : _rootsTracker = rootsTracker,
        _analyze = analyze ?? (service ?? CockpitAnalyzeFilesService()).analyze;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitAnalyzeFilesToolFunction _analyze;

  @override
  String get name => 'analyze_files';

  @override
  String get description =>
      'Run analyzer on a bounded set of files or directories and return concise diagnostics.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: true,
        requiresSession: false,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.workspaceQuality,
        CockpitMcpFeatureCategory.codeIntelligence,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['paths'],
        'properties': <String, Object?>{
          'workspaceRoot': <String, Object?>{'type': 'string'},
          'paths': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{'type': 'string'},
          },
          'maxDiagnostics': <String, Object?>{'type': 'integer'},
          'maxOutputChars': <String, Object?>{'type': 'integer'},
          'timeoutSeconds': <String, Object?>{'type': 'integer'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final workspaceRoot = cockpitResolveWorkspaceRootFromArguments(
        arguments,
        _rootsTracker,
      );
      final result = await _analyze(
        CockpitAnalyzeFilesRequest(
          workspaceRoot: workspaceRoot,
          paths: cockpitReadOptionalStringList(arguments, 'paths'),
          allowedRoots: cockpitAllowedWorkspaceRootPaths(_rootsTracker),
          maxDiagnostics: cockpitReadOptionalPositiveInt(
                arguments,
                'maxDiagnostics',
              ) ??
              50,
          maxOutputChars: cockpitReadOptionalPositiveInt(
                arguments,
                'maxOutputChars',
              ) ??
              1600,
          timeout: Duration(
            seconds: cockpitReadOptionalPositiveInt(
                  arguments,
                  'timeoutSeconds',
                ) ??
                120,
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Focused analysis completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
