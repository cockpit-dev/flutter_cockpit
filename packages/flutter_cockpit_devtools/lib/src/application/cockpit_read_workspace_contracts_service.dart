import '../infrastructure/cockpit_file_system.dart';
import 'cockpit_read_workspace_goals_service.dart';

final class CockpitWorkspaceContracts {
  const CockpitWorkspaceContracts({
    required this.skillContract,
    required this.bundleContract,
  });

  final CockpitWorkspaceDocument skillContract;
  final CockpitWorkspaceDocument bundleContract;

  Map<String, Object?> toJson() => <String, Object?>{
        'skillContract': skillContract.toJson(),
        'bundleContract': bundleContract.toJson(),
      };
}

final class CockpitReadWorkspaceContractsService {
  CockpitReadWorkspaceContractsService({
    CockpitFileSystem? fileSystem,
  }) : _fileSystem = fileSystem ?? const LocalCockpitFileSystem();

  final CockpitFileSystem _fileSystem;

  Future<CockpitWorkspaceContracts> read({
    String skillContractPath =
        'docs/contracts/flutter-cockpit-skill-contract.md',
    String bundleContractPath = 'docs/contracts/task-run-bundle.md',
  }) async {
    return CockpitWorkspaceContracts(
      skillContract:
          await readSkillContract(skillContractPath: skillContractPath),
      bundleContract:
          await readBundleContract(bundleContractPath: bundleContractPath),
    );
  }

  Future<CockpitWorkspaceDocument> readSkillContract({
    String skillContractPath =
        'docs/contracts/flutter-cockpit-skill-contract.md',
  }) async {
    final skillContract = _fileSystem.file(skillContractPath);
    return CockpitWorkspaceDocument(
      path: skillContract.path,
      text: await skillContract.readAsString(),
    );
  }

  Future<CockpitWorkspaceDocument> readBundleContract({
    String bundleContractPath = 'docs/contracts/task-run-bundle.md',
  }) async {
    final bundleContract = _fileSystem.file(bundleContractPath);
    return CockpitWorkspaceDocument(
      path: bundleContract.path,
      text: await bundleContract.readAsString(),
    );
  }
}
