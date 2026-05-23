import '../../application/cockpit_format_workspace_service.dart';
import '../../application/cockpit_workspace_command_result.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitFormatWorkspaceToolFunction
    = Future<CockpitWorkspaceCommandResult> Function(
  CockpitFormatWorkspaceRequest request,
);

final class CockpitFormatWorkspaceTool extends CockpitMcpTool {
  CockpitFormatWorkspaceTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitFormatWorkspaceService? service,
    CockpitFormatWorkspaceToolFunction? format,
  })  : _rootsTracker = rootsTracker,
        _format = format ?? (service ?? CockpitFormatWorkspaceService()).format;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitFormatWorkspaceToolFunction _format;

  @override
  String get name => 'format_workspace';

  @override
  String get description => 'Run dart format for a workspace root.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: false,
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
      final result = await _format(
        CockpitFormatWorkspaceRequest(
          workspaceRoot: workspaceRoot,
          allowedRoots: cockpitAllowedWorkspaceRootPaths(_rootsTracker),
          timeout: Duration(
            seconds: cockpitReadOptionalPositiveInt(
                  arguments,
                  'timeoutSeconds',
                ) ??
                90,
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Workspace formatting completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
