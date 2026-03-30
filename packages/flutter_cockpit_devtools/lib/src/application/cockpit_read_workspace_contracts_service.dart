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
    final skillContract = _fileSystem.file(skillContractPath);
    final bundleContract = _fileSystem.file(bundleContractPath);
    return CockpitWorkspaceContracts(
      skillContract: CockpitWorkspaceDocument(
        path: skillContract.path,
        text: await skillContract.readAsString(),
      ),
      bundleContract: CockpitWorkspaceDocument(
        path: bundleContract.path,
        text: await bundleContract.readAsString(),
      ),
    );
  }
}
