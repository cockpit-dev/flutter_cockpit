import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:test/test.dart';

void main() {
  group('LocalCockpitFileSystem', () {
    test('creates file and directory handles from the injected file system',
        () {
      final delegate = MemoryFileSystem();
      final fileSystem = LocalCockpitFileSystem(fileSystem: delegate);

      final file = fileSystem.file('/workspace/bundle/manifest.json');
      final directory = fileSystem.directory('/workspace/bundle/screenshots');

      delegate.directory('/workspace/bundle').createSync(recursive: true);
      file.writeAsStringSync('{"ok":true}');
      directory.createSync(recursive: true);

      expect(
        delegate.file('/workspace/bundle/manifest.json').readAsStringSync(),
        '{"ok":true}',
      );
      expect(
        delegate.directory('/workspace/bundle/screenshots').existsSync(),
        isTrue,
      );
    });

    test('creates temporary directories through the injected file system',
        () async {
      final delegate = MemoryFileSystem();
      final fileSystem = LocalCockpitFileSystem(fileSystem: delegate);

      final tempDirectory = await fileSystem.systemTemp('cockpit-artifacts');

      expect(tempDirectory.existsSync(), isTrue);
      expect(tempDirectory.path, contains('cockpit-artifacts'));
    });
  });
}
