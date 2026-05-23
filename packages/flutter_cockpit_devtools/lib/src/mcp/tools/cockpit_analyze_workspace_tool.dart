import '../../application/cockpit_analyze_workspace_service.dart';
import '../../application/cockpit_workspace_command_result.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitAnalyzeWorkspaceToolFunction
    = Future<CockpitWorkspaceCommandResult> Function(
  CockpitAnalyzeWorkspaceRequest request,
);

final class CockpitAnalyzeWorkspaceTool extends CockpitMcpTool {
  CockpitAnalyzeWorkspaceTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitAnalyzeWorkspaceService? service,
    CockpitAnalyzeWorkspaceToolFunction? analyze,
  })  : _rootsTracker = rootsTracker,
        _analyze =
            analyze ?? (service ?? CockpitAnalyzeWorkspaceService()).analyze;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitAnalyzeWorkspaceToolFunction _analyze;

  @override
  String get name => 'analyze_workspace';

  @override
  String get description =>
      'Run analyzer for a Dart or Flutter workspace under the configured roots.';

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
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'workspaceRoot': <String, Object?>{'type': 'string'},
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
        CockpitAnalyzeWorkspaceRequest(
          workspaceRoot: workspaceRoot,
          allowedRoots: cockpitAllowedWorkspaceRootPaths(_rootsTracker),
          timeout: Duration(
            seconds: cockpitReadOptionalPositiveInt(
                  arguments,
                  'timeoutSeconds',
                ) ??
                180,
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Workspace analysis completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
