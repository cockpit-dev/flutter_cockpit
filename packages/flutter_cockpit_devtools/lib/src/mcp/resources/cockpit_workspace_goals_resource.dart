import '../../application/cockpit_read_workspace_goals_service.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitWorkspaceGoalsResource extends CockpitMcpResource {
  CockpitWorkspaceGoalsResource({
    CockpitReadWorkspaceGoalsService? service,
    this.goalsFilePath = 'GOALS.md',
  }) : _service = service ?? CockpitReadWorkspaceGoalsService();

  final CockpitReadWorkspaceGoalsService _service;
  final String goalsFilePath;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspace_goals',
        uri: 'cockpit://workspace/goals',
        description: 'Repository goals that define flutter_cockpit success.',
        mimeType: 'text/markdown',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(CockpitMcpResourceRequest request) async {
    if (request.uri != definition.uri) {
      return null;
    }

    final document = await _service.read(goalsFilePath: goalsFilePath);
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: document.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}
