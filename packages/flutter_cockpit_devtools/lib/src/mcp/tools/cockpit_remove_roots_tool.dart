import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_roots_tracker.dart';
import '../core/cockpit_mcp_workspace_tooling_support.dart';

final class CockpitRemoveRootsTool extends CockpitMcpTool {
  CockpitRemoveRootsTool({required CockpitMcpRootsTracker rootsTracker})
      : _rootsTracker = rootsTracker;

  final CockpitMcpRootsTracker _rootsTracker;

  @override
  String get name => 'remove_roots';

  @override
  String get description =>
      'Remove fallback project roots previously registered through add_roots.';

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
        'required': <String>['uris'],
        'properties': <String, Object?>{
          'uris': <String, Object?>{
            'type': 'array',
            'items': <String, Object?>{'type': 'string'},
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
    _rootsTracker
        .removeFallbackRoots(cockpitReadOptionalStringList(arguments, 'uris'));
    return cockpitMcpResult(
      text: 'Fallback roots removed.',
      structuredContent: _rootsTracker.toJson(),
    );
  }
}
