import '../../application/cockpit_read_workspace_contracts_service.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitWorkspaceProtocolResource extends CockpitMcpResource {
  CockpitWorkspaceProtocolResource({
    CockpitReadWorkspaceContractsService? service,
    this.protocolPath = 'docs/contracts/flutter-cockpit-protocol.md',
  }) : _service = service ?? CockpitReadWorkspaceContractsService();

  final CockpitReadWorkspaceContractsService _service;
  final String protocolPath;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspace_protocol',
        uri: 'cockpit://workspace/protocol',
        description:
            'The Flutter Cockpit protocol entry point and contract map.',
        mimeType: 'text/markdown',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final protocol = await _service.readProtocol(protocolPath: protocolPath);
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: protocol.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

final class CockpitWorkspaceAiDevelopmentProtocolResource
    extends CockpitMcpResource {
  CockpitWorkspaceAiDevelopmentProtocolResource({
    CockpitReadWorkspaceContractsService? service,
    this.aiDevelopmentProtocolPath =
        'docs/contracts/ai-development-protocol.md',
  }) : _service = service ?? CockpitReadWorkspaceContractsService();

  final CockpitReadWorkspaceContractsService _service;
  final String aiDevelopmentProtocolPath;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspace_ai_development_protocol',
        uri: 'cockpit://workspace/ai-development-protocol',
        description: 'The AI-first development protocol for Flutter Cockpit.',
        mimeType: 'text/markdown',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final protocol = await _service.readAiDevelopmentProtocol(
      aiDevelopmentProtocolPath: aiDevelopmentProtocolPath,
    );
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: protocol.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

final class CockpitWorkspaceSkillContractResource extends CockpitMcpResource {
  CockpitWorkspaceSkillContractResource({
    CockpitReadWorkspaceContractsService? service,
    this.skillContractPath = 'docs/contracts/flutter-cockpit-skill-contract.md',
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
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final skillContract = await _service.readSkillContract(
      skillContractPath: skillContractPath,
    );
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: skillContract.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

final class CockpitWorkspaceTaskBundleContractResource
    extends CockpitMcpResource {
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
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final bundleContract = await _service.readBundleContract(
      bundleContractPath: bundleContractPath,
    );
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: bundleContract.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

final class CockpitWorkspaceWorkflowProtocolResource
    extends CockpitMcpResource {
  CockpitWorkspaceWorkflowProtocolResource({
    CockpitReadWorkspaceContractsService? service,
    this.workflowProtocolPath = 'docs/contracts/control-workflow-protocol.md',
  }) : _service = service ?? CockpitReadWorkspaceContractsService();

  final CockpitReadWorkspaceContractsService _service;
  final String workflowProtocolPath;

  @override
  CockpitMcpResourceDefinition
  get definition => const CockpitMcpResourceDefinition.fixed(
    name: 'workspace_control_workflow_protocol',
    uri: 'cockpit://workspace/control-workflow-protocol',
    description:
        'The control workflow protocol used by run-script and validation flows.',
    mimeType: 'text/markdown',
    categories: <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.workspace,
      CockpitMcpFeatureCategory.contextResources,
    ],
  );

  @override
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final workflowProtocol = await _service.readWorkflowProtocol(
      workflowProtocolPath: workflowProtocolPath,
    );
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: workflowProtocol.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}

final class CockpitWorkspaceWorkflowSchemaResource extends CockpitMcpResource {
  CockpitWorkspaceWorkflowSchemaResource({
    CockpitReadWorkspaceContractsService? service,
    this.workflowSchemaPath = 'docs/contracts/control-workflow.schema.json',
  }) : _service = service ?? CockpitReadWorkspaceContractsService();

  final CockpitReadWorkspaceContractsService _service;
  final String workflowSchemaPath;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspace_control_workflow_schema',
        uri: 'cockpit://workspace/control-workflow-schema',
        description:
            'The JSON Schema for Flutter Cockpit control workflow scripts.',
        mimeType: 'application/schema+json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final workflowSchema = await _service.readWorkflowSchema(
      workflowSchemaPath: workflowSchemaPath,
    );
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: workflowSchema.text,
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}
