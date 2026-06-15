import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_workspace_contracts_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:test/test.dart';

void main() {
  test('reads workspace contracts and workflow protocol', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/docs/contracts/ai-development-protocol.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# AI Development Protocol');
    fileSystem.file(
        '/workspace/docs/contracts/flutter-cockpit-skill-contract.md',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('# Skill Contract');
    fileSystem.file('/workspace/docs/contracts/task-run-bundle.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Bundle Contract');
    fileSystem.file('/workspace/docs/contracts/control-workflow-protocol.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Workflow Protocol');
    fileSystem.file('/workspace/docs/contracts/control-workflow.schema.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"title":"Workflow Schema"}');

    final service = CockpitReadWorkspaceContractsService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
    );

    final result = await service.read(
      aiDevelopmentProtocolPath:
          '/workspace/docs/contracts/ai-development-protocol.md',
      skillContractPath:
          '/workspace/docs/contracts/flutter-cockpit-skill-contract.md',
      bundleContractPath: '/workspace/docs/contracts/task-run-bundle.md',
      workflowProtocolPath:
          '/workspace/docs/contracts/control-workflow-protocol.md',
      workflowSchemaPath:
          '/workspace/docs/contracts/control-workflow.schema.json',
    );

    expect(result.aiDevelopmentProtocol.text, '# AI Development Protocol');
    expect(result.skillContract.text, '# Skill Contract');
    expect(result.bundleContract.text, '# Bundle Contract');
    expect(result.workflowProtocol.text, '# Workflow Protocol');
    expect(result.workflowSchema.text, '{"title":"Workflow Schema"}');
    expect(
      result.toJson()['aiDevelopmentProtocol'],
      isA<Map<String, Object?>>(),
    );
    expect(result.toJson()['skillContract'], isA<Map<String, Object?>>());
    expect(result.toJson()['workflowProtocol'], isA<Map<String, Object?>>());
    expect(result.toJson()['workflowSchema'], isA<Map<String, Object?>>());
  });

  test(
    'reads the AI development protocol without requiring other contract paths',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/docs/contracts/ai-development-protocol.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('# AI Development Protocol');

      final service = CockpitReadWorkspaceContractsService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      );

      final result = await service.readAiDevelopmentProtocol(
        aiDevelopmentProtocolPath:
            '/workspace/docs/contracts/ai-development-protocol.md',
      );

      expect(result.text, '# AI Development Protocol');
    },
  );

  test(
    'reads the skill contract without requiring the bundle contract path',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file(
          '/workspace/docs/contracts/flutter-cockpit-skill-contract.md',
        )
        ..createSync(recursive: true)
        ..writeAsStringSync('# Skill Contract');

      final service = CockpitReadWorkspaceContractsService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      );

      final result = await service.readSkillContract(
        skillContractPath:
            '/workspace/docs/contracts/flutter-cockpit-skill-contract.md',
      );

      expect(result.text, '# Skill Contract');
    },
  );

  test(
    'reads the bundle contract without requiring the skill contract path',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/docs/contracts/task-run-bundle.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('# Bundle Contract');

      final service = CockpitReadWorkspaceContractsService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      );

      final result = await service.readBundleContract(
        bundleContractPath: '/workspace/docs/contracts/task-run-bundle.md',
      );

      expect(result.text, '# Bundle Contract');
    },
  );

  test(
    'reads the workflow protocol without requiring other contract paths',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/docs/contracts/control-workflow-protocol.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('# Workflow Protocol');

      final service = CockpitReadWorkspaceContractsService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      );

      final result = await service.readWorkflowProtocol(
        workflowProtocolPath:
            '/workspace/docs/contracts/control-workflow-protocol.md',
      );

      expect(result.text, '# Workflow Protocol');
    },
  );

  test(
    'reads the workflow schema without requiring other contract paths',
    () async {
      final fileSystem = MemoryFileSystem();
      fileSystem.file('/workspace/docs/contracts/control-workflow.schema.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"title":"Workflow Schema"}');

      final service = CockpitReadWorkspaceContractsService(
        fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
      );

      final result = await service.readWorkflowSchema(
        workflowSchemaPath:
            '/workspace/docs/contracts/control-workflow.schema.json',
      );

      expect(result.text, '{"title":"Workflow Schema"}');
    },
  );

  test('published package includes fallback contract copies', () {
    final packageRoot =
        Directory.current.path.endsWith('packages/flutter_cockpit_devtools')
        ? Directory.current
        : Directory('packages/flutter_cockpit_devtools');

    expect(
      File(
        '${packageRoot.path}/doc/contracts/ai-development-protocol.md',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${packageRoot.path}/doc/contracts/flutter-cockpit-skill-contract.md',
      ).existsSync(),
      isTrue,
    );
    expect(
      File('${packageRoot.path}/doc/contracts/task-run-bundle.md').existsSync(),
      isTrue,
    );
    expect(
      File(
        '${packageRoot.path}/doc/contracts/control-workflow-protocol.md',
      ).existsSync(),
      isTrue,
    );
    expect(
      File(
        '${packageRoot.path}/doc/contracts/control-workflow.schema.json',
      ).existsSync(),
      isTrue,
    );
  });

  test('falls back to package-local contracts when workspace docs are absent', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file(
        '/workspace/packages/flutter_cockpit_devtools/doc/contracts/ai-development-protocol.md',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('# Package AI Development Protocol');
    fileSystem.file(
        '/workspace/packages/flutter_cockpit_devtools/doc/contracts/flutter-cockpit-skill-contract.md',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('# Package Skill Contract');
    fileSystem.file(
        '/workspace/packages/flutter_cockpit_devtools/doc/contracts/task-run-bundle.md',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('# Package Bundle Contract');
    fileSystem.file(
        '/workspace/packages/flutter_cockpit_devtools/doc/contracts/control-workflow-protocol.md',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('# Package Workflow Protocol');
    fileSystem.file(
        '/workspace/packages/flutter_cockpit_devtools/doc/contracts/control-workflow.schema.json',
      )
      ..createSync(recursive: true)
      ..writeAsStringSync('{"title":"Package Workflow Schema"}');
    fileSystem.currentDirectory = '/workspace';

    final service = CockpitReadWorkspaceContractsService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
    );

    final result = await service.read();

    expect(
      result.aiDevelopmentProtocol.text,
      '# Package AI Development Protocol',
    );
    expect(result.skillContract.text, '# Package Skill Contract');
    expect(result.bundleContract.text, '# Package Bundle Contract');
    expect(result.workflowProtocol.text, '# Package Workflow Protocol');
    expect(result.workflowSchema.text, '{"title":"Package Workflow Schema"}');
  });

  test('falls back when the current directory is the package root', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/package/doc/contracts/ai-development-protocol.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Local AI Development Protocol');
    fileSystem.file('/package/doc/contracts/flutter-cockpit-skill-contract.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Local Skill Contract');
    fileSystem.file('/package/doc/contracts/task-run-bundle.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Local Bundle Contract');
    fileSystem.file('/package/doc/contracts/control-workflow-protocol.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Local Workflow Protocol');
    fileSystem.file('/package/doc/contracts/control-workflow.schema.json')
      ..createSync(recursive: true)
      ..writeAsStringSync('{"title":"Local Workflow Schema"}');
    fileSystem.currentDirectory = '/package';

    final service = CockpitReadWorkspaceContractsService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
    );

    final result = await service.read();

    expect(
      result.aiDevelopmentProtocol.text,
      '# Local AI Development Protocol',
    );
    expect(result.skillContract.text, '# Local Skill Contract');
    expect(result.bundleContract.text, '# Local Bundle Contract');
    expect(result.workflowProtocol.text, '# Local Workflow Protocol');
    expect(result.workflowSchema.text, '{"title":"Local Workflow Schema"}');
  });
}
