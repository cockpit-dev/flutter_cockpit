import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_workspace_contracts_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_resource.dart';
import 'package:flutter_cockpit_devtools/src/mcp/resources/cockpit_workspace_contracts_resource.dart';
import 'package:test/test.dart';

void main() {
  test(
    'skill contract resource reads only the configured skill file',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file(
          '/workspace/docs/contracts/flutter-cockpit-skill-contract.md',
        )
        ..createSync(recursive: true)
        ..writeAsStringSync('# Skill Contract');

      final resource = CockpitWorkspaceSkillContractResource(
        service: CockpitReadWorkspaceContractsService(
          fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        ),
        skillContractPath:
            '/workspace/docs/contracts/flutter-cockpit-skill-contract.md',
      );

      final result = await resource.read(
        const CockpitMcpResourceRequest(
          uri: 'cockpit://workspace/skill-contract',
        ),
      );

      expect(result, isNotNull);
      final contents =
          result!.contents.single as CockpitMcpTextResourceContents;
      expect(contents.text, '# Skill Contract');
    },
  );

  test(
    'bundle contract resource reads only the configured bundle file',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/docs/contracts/task-run-bundle.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('# Bundle Contract');

      final resource = CockpitWorkspaceTaskBundleContractResource(
        service: CockpitReadWorkspaceContractsService(
          fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        ),
        bundleContractPath: '/workspace/docs/contracts/task-run-bundle.md',
      );

      final result = await resource.read(
        const CockpitMcpResourceRequest(
          uri: 'cockpit://workspace/task-bundle-contract',
        ),
      );

      expect(result, isNotNull);
      final contents =
          result!.contents.single as CockpitMcpTextResourceContents;
      expect(contents.text, '# Bundle Contract');
    },
  );
}
