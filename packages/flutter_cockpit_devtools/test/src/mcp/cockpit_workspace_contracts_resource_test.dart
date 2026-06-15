import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_workspace_contracts_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_resource.dart';
import 'package:flutter_cockpit_devtools/src/mcp/resources/cockpit_workspace_contracts_resource.dart';
import 'package:test/test.dart';

void main() {
  test('protocol resource reads only the configured protocol file', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/docs/contracts/flutter-cockpit-protocol.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Flutter Cockpit Protocol');

    final resource = CockpitWorkspaceProtocolResource(
      service: CockpitReadWorkspaceContractsService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      ),
      protocolPath: '/workspace/docs/contracts/flutter-cockpit-protocol.md',
    );

    final result = await resource.read(
      const CockpitMcpResourceRequest(uri: 'cockpit://workspace/protocol'),
    );

    expect(result, isNotNull);
    final contents = result!.contents.single as CockpitMcpTextResourceContents;
    expect(contents.text, '# Flutter Cockpit Protocol');
  });

  test(
    'AI development protocol resource reads only the configured protocol file',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/docs/contracts/ai-development-protocol.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('# AI Development Protocol');

      final resource = CockpitWorkspaceAiDevelopmentProtocolResource(
        service: CockpitReadWorkspaceContractsService(
          fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        ),
        aiDevelopmentProtocolPath:
            '/workspace/docs/contracts/ai-development-protocol.md',
      );

      final result = await resource.read(
        const CockpitMcpResourceRequest(
          uri: 'cockpit://workspace/ai-development-protocol',
        ),
      );

      expect(result, isNotNull);
      final contents =
          result!.contents.single as CockpitMcpTextResourceContents;
      expect(contents.text, '# AI Development Protocol');
    },
  );

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

  test(
    'workflow protocol resource reads only the configured protocol file',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/docs/contracts/control-workflow-protocol.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('# Workflow Protocol');

      final resource = CockpitWorkspaceWorkflowProtocolResource(
        service: CockpitReadWorkspaceContractsService(
          fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        ),
        workflowProtocolPath:
            '/workspace/docs/contracts/control-workflow-protocol.md',
      );

      final result = await resource.read(
        const CockpitMcpResourceRequest(
          uri: 'cockpit://workspace/control-workflow-protocol',
        ),
      );

      expect(result, isNotNull);
      final contents =
          result!.contents.single as CockpitMcpTextResourceContents;
      expect(contents.text, '# Workflow Protocol');
    },
  );

  test(
    'workflow schema resource reads only the configured schema file',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/docs/contracts/control-workflow.schema.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"title":"Workflow Schema"}');

      final resource = CockpitWorkspaceWorkflowSchemaResource(
        service: CockpitReadWorkspaceContractsService(
          fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
        ),
        workflowSchemaPath:
            '/workspace/docs/contracts/control-workflow.schema.json',
      );

      final result = await resource.read(
        const CockpitMcpResourceRequest(
          uri: 'cockpit://workspace/control-workflow-schema',
        ),
      );

      expect(result, isNotNull);
      final contents =
          result!.contents.single as CockpitMcpTextResourceContents;
      expect(contents.text, '{"title":"Workflow Schema"}');
      expect(contents.mimeType, 'application/schema+json');
    },
  );
}
