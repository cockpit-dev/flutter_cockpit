import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_workspace_contracts_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:test/test.dart';

void main() {
  test('reads both workspace contracts', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/docs/contracts/flutter-cockpit-skill-contract.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Skill Contract');
    fileSystem.file('/workspace/docs/contracts/task-run-bundle.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Bundle Contract');

    final service = CockpitReadWorkspaceContractsService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
    );

    final result = await service.read(
      skillContractPath:
          '/workspace/docs/contracts/flutter-cockpit-skill-contract.md',
      bundleContractPath: '/workspace/docs/contracts/task-run-bundle.md',
    );

    expect(result.skillContract.text, '# Skill Contract');
    expect(result.bundleContract.text, '# Bundle Contract');
    expect(result.toJson()['skillContract'], isA<Map<String, Object?>>());
  });
}
