import '../infrastructure/cockpit_file_system.dart';
import 'cockpit_workspace_document.dart';

final class CockpitWorkspaceContracts {
  const CockpitWorkspaceContracts({
    required this.protocol,
    required this.aiDevelopmentProtocol,
    required this.skillContract,
    required this.bundleContract,
    required this.workflowProtocol,
    required this.workflowSchema,
  });

  final CockpitWorkspaceDocument protocol;
  final CockpitWorkspaceDocument aiDevelopmentProtocol;
  final CockpitWorkspaceDocument skillContract;
  final CockpitWorkspaceDocument bundleContract;
  final CockpitWorkspaceDocument workflowProtocol;
  final CockpitWorkspaceDocument workflowSchema;

  Map<String, Object?> toJson() => <String, Object?>{
    'protocol': protocol.toJson(),
    'aiDevelopmentProtocol': aiDevelopmentProtocol.toJson(),
    'skillContract': skillContract.toJson(),
    'bundleContract': bundleContract.toJson(),
    'workflowProtocol': workflowProtocol.toJson(),
    'workflowSchema': workflowSchema.toJson(),
  };
}

final class CockpitReadWorkspaceContractsService {
  CockpitReadWorkspaceContractsService({CockpitFileSystem? fileSystem})
    : _fileSystem = fileSystem ?? const LocalCockpitFileSystem();

  final CockpitFileSystem _fileSystem;

  Future<CockpitWorkspaceContracts> read({
    String protocolPath = 'docs/contracts/flutter-cockpit-protocol.md',
    String aiDevelopmentProtocolPath =
        'docs/contracts/ai-development-protocol.md',
    String skillContractPath =
        'docs/contracts/flutter-cockpit-skill-contract.md',
    String bundleContractPath = 'docs/contracts/task-run-bundle.md',
    String workflowProtocolPath = 'docs/contracts/control-workflow-protocol.md',
    String workflowSchemaPath = 'docs/contracts/control-workflow.schema.json',
  }) async {
    return CockpitWorkspaceContracts(
      protocol: await readProtocol(protocolPath: protocolPath),
      aiDevelopmentProtocol: await readAiDevelopmentProtocol(
        aiDevelopmentProtocolPath: aiDevelopmentProtocolPath,
      ),
      skillContract: await readSkillContract(
        skillContractPath: skillContractPath,
      ),
      bundleContract: await readBundleContract(
        bundleContractPath: bundleContractPath,
      ),
      workflowProtocol: await readWorkflowProtocol(
        workflowProtocolPath: workflowProtocolPath,
      ),
      workflowSchema: await readWorkflowSchema(
        workflowSchemaPath: workflowSchemaPath,
      ),
    );
  }

  Future<CockpitWorkspaceDocument> readProtocol({
    String protocolPath = 'docs/contracts/flutter-cockpit-protocol.md',
  }) async {
    return _readDocumentWithPackageFallback(
      path: protocolPath,
      packageRelativePath: 'doc/contracts/flutter-cockpit-protocol.md',
    );
  }

  Future<CockpitWorkspaceDocument> readAiDevelopmentProtocol({
    String aiDevelopmentProtocolPath =
        'docs/contracts/ai-development-protocol.md',
  }) async {
    return _readDocumentWithPackageFallback(
      path: aiDevelopmentProtocolPath,
      packageRelativePath: 'doc/contracts/ai-development-protocol.md',
    );
  }

  Future<CockpitWorkspaceDocument> readSkillContract({
    String skillContractPath =
        'docs/contracts/flutter-cockpit-skill-contract.md',
  }) async {
    return _readDocumentWithPackageFallback(
      path: skillContractPath,
      packageRelativePath: 'doc/contracts/flutter-cockpit-skill-contract.md',
    );
  }

  Future<CockpitWorkspaceDocument> readBundleContract({
    String bundleContractPath = 'docs/contracts/task-run-bundle.md',
  }) async {
    return _readDocumentWithPackageFallback(
      path: bundleContractPath,
      packageRelativePath: 'doc/contracts/task-run-bundle.md',
    );
  }

  Future<CockpitWorkspaceDocument> readWorkflowProtocol({
    String workflowProtocolPath = 'docs/contracts/control-workflow-protocol.md',
  }) async {
    return _readDocumentWithPackageFallback(
      path: workflowProtocolPath,
      packageRelativePath: 'doc/contracts/control-workflow-protocol.md',
    );
  }

  Future<CockpitWorkspaceDocument> readWorkflowSchema({
    String workflowSchemaPath = 'docs/contracts/control-workflow.schema.json',
  }) async {
    return _readDocumentWithPackageFallback(
      path: workflowSchemaPath,
      packageRelativePath: 'doc/contracts/control-workflow.schema.json',
    );
  }

  Future<CockpitWorkspaceDocument> _readDocumentWithPackageFallback({
    required String path,
    required String packageRelativePath,
  }) async {
    final candidates = <String>[
      path,
      packageRelativePath,
      _fileSystem.pathContext.join(
        'packages',
        'flutter_cockpit_devtools',
        packageRelativePath,
      ),
    ];
    final file = candidates
        .map(_fileSystem.file)
        .firstWhere((candidate) => candidate.existsSync());
    return CockpitWorkspaceDocument(
      path: file.path,
      text: await file.readAsString(),
    );
  }
}
