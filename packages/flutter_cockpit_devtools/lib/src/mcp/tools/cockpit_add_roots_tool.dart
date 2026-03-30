import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

final class CockpitAddRootsTool extends CockpitMcpTool {
  CockpitAddRootsTool({required CockpitMcpRootsTracker rootsTracker})
      : _rootsTracker = rootsTracker;

  final CockpitMcpRootsTracker _rootsTracker;

  @override
  String get name => 'add_roots';

  @override
  String get description =>
      'Add fallback project roots when the MCP client does not provide native roots.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: false,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: false,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[CockpitMcpFeatureCategory.roots];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>['roots'],
        'properties': <String, Object?>{
          'roots': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{
              'type': 'object',
              'required': <String>['uri'],
              'properties': <String, Object?>{
                'uri': <String, Object?>{'type': 'string'},
                'name': <String, Object?>{'type': 'string'},
              },
            },
          },
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    if (!_rootsTracker.fallbackActive) {
      throw CockpitMcpError.invalidArguments(
        'Fallback roots are not active for this MCP session.',
      );
    }
    final roots = cockpitReadRootObjects(arguments);
    _rootsTracker.addFallbackRoots(roots);
    return cockpitMcpResult(
      text: 'Fallback roots added.',
      structuredContent: _rootsTracker.toJson(),
    );
  }
}
