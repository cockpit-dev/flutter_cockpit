import '../../application/cockpit_apply_workspace_fixes_service.dart';
import '../../application/cockpit_workspace_command_result.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitApplyWorkspaceFixesToolFunction
    = Future<CockpitWorkspaceCommandResult> Function(
  CockpitApplyWorkspaceFixesRequest request,
);

final class CockpitApplyWorkspaceFixesTool extends CockpitMcpTool {
  CockpitApplyWorkspaceFixesTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitApplyWorkspaceFixesService? service,
    CockpitApplyWorkspaceFixesToolFunction? apply,
  })  : _rootsTracker = rootsTracker,
        _apply =
            apply ?? (service ?? CockpitApplyWorkspaceFixesService()).apply;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitApplyWorkspaceFixesToolFunction _apply;

  @override
  String get name => 'apply_fixes';

  @override
  String get description => 'Run dart fix --apply for a workspace root.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: false,
        destructive: false,
        idempotent: false,
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
      final result = await _apply(
        CockpitApplyWorkspaceFixesRequest(
          workspaceRoot: workspaceRoot,
          allowedRoots: cockpitAllowedWorkspaceRootPaths(_rootsTracker),
          timeout: Duration(
            seconds: cockpitReadOptionalInt(arguments, 'timeoutSeconds') ?? 180,
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Workspace fixes applied.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
