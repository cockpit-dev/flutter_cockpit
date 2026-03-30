import '../../application/cockpit_read_workspace_contracts_service.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitWorkspaceSkillContractResource extends CockpitMcpResource {
  CockpitWorkspaceSkillContractResource({
    CockpitReadWorkspaceContractsService? service,
    this.skillContractPath =
        'docs/contracts/flutter-cockpit-skill-contract.md',
  }) : _service = service ?? CockpitReadWorkspaceContractsService();

  final CockpitReadWorkspaceContractsService _service;
  final String skillContractPath;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspace_skill_contract',
        uri: 'cockpit://workspace/skill-contract',
        description: 'The maintainer-facing flutter_cockpit skill contract.',
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
    final contracts = await _service.read(skillContractPath: skillContractPath);
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: contracts.skillContract.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

final class CockpitWorkspaceTaskBundleContractResource extends CockpitMcpResource {
  CockpitWorkspaceTaskBundleContractResource({
    CockpitReadWorkspaceContractsService? service,
    this.bundleContractPath = 'docs/contracts/task-run-bundle.md',
  }) : _service = service ?? CockpitReadWorkspaceContractsService();

  final CockpitReadWorkspaceContractsService _service;
  final String bundleContractPath;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspace_task_bundle_contract',
        uri: 'cockpit://workspace/task-bundle-contract',
        description: 'The task-run bundle contract used for delivery.',
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
    final contracts = await _service.read(bundleContractPath: bundleContractPath);
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: contracts.bundleContract.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}
