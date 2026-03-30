import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_workspace_goals_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:test/test.dart';

void main() {
  test('reads the goals document from the configured path', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/GOALS.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('# Goals\n\nShip the loop.');

    final service = CockpitReadWorkspaceGoalsService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
    );

    final result = await service.read(
      goalsFilePath: '/workspace/GOALS.md',
    );

    expect(result.path, '/workspace/GOALS.md');
    expect(result.text, contains('Ship the loop.'));
    expect(result.toJson()['path'], '/workspace/GOALS.md');
  });
}
