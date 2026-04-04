import '../../application/cockpit_json_key_normalizer.dart';
import '../../application/cockpit_list_workspace_roots_service.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitWorkspaceRootsResource extends CockpitMcpResource {
  const CockpitWorkspaceRootsResource({
    required CockpitListWorkspaceRootsService service,
  }) : _service = service;

  final CockpitListWorkspaceRootsService _service;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspaceRoots',
        uri: 'cockpit://workspace/roots',
        description: 'The effective workspace roots for this MCP server.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.roots,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
      CockpitMcpResourceRequest request) async {
    if (request.uri != definition.uri) {
      return null;
    }
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: cockpitPrettyJsonText(_service.list()),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}
