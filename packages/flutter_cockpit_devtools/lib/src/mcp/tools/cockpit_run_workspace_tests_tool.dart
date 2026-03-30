import '../../application/cockpit_run_workspace_tests_service.dart';
import '../../application/cockpit_workspace_command_result.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

typedef CockpitRunWorkspaceTestsToolFunction
    = Future<CockpitWorkspaceCommandResult> Function(
  CockpitRunWorkspaceTestsRequest request,
);

final class CockpitRunWorkspaceTestsTool extends CockpitMcpTool {
  CockpitRunWorkspaceTestsTool({
    required CockpitMcpRootsTracker rootsTracker,
    CockpitRunWorkspaceTestsService? service,
    CockpitRunWorkspaceTestsToolFunction? runTests,
  })  : _rootsTracker = rootsTracker,
        _runTests =
            runTests ?? (service ?? CockpitRunWorkspaceTestsService()).run;

  final CockpitMcpRootsTracker _rootsTracker;
  final CockpitRunWorkspaceTestsToolFunction _runTests;

  @override
  String get name => 'run_tests';

  @override
  String get description => 'Run unit/widget tests for a workspace root.';

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
          'workspace_root': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final workspaceRoot = cockpitResolveWorkspaceRootFromArguments(
        arguments,
        _rootsTracker,
      );
      final result = await _runTests(
        CockpitRunWorkspaceTestsRequest(
          workspaceRoot: workspaceRoot,
          allowedRoots: cockpitAllowedWorkspaceRootPaths(_rootsTracker),
        ),
      );
      return cockpitMcpResult(
        text: 'Workspace tests completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
