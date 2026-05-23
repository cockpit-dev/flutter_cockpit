import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_package_uris_service.dart';
import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_file_system.dart';
import 'package:test/test.dart';

void main() {
  test('reads package and package-root URIs from package_config', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode(<String, Object?>{
          'configVersion': 2,
          'packages': <Map<String, Object?>>[
            <String, Object?>{
              'name': 'example_pkg',
              'rootUri': 'file:///deps/example_pkg/',
              'packageUri': 'lib/',
              'languageVersion': '3.5',
            },
          ],
        }),
      );
    fileSystem.file('/deps/example_pkg/lib/example_pkg.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('library example_pkg;');
    fileSystem.file('/deps/example_pkg/example/demo.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}');

    final service = CockpitReadPackageUrisService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
    );

    final libraryResult = await service.read(
      const CockpitReadPackageUrisRequest(
        workspaceRoot: '/workspace',
        uri: 'package:example_pkg/example_pkg.dart',
      ),
    );
    expect(libraryResult.kind, CockpitPackageUriEntryKind.file);
    expect(libraryResult.contentKind, CockpitPackageUriContentKind.text);
    expect(libraryResult.preview, 'library example_pkg;');
    expect(libraryResult.truncated, isFalse);
    expect(libraryResult.text, isNull);

    final rootResult = await service.read(
      const CockpitReadPackageUrisRequest(
        workspaceRoot: '/workspace',
        uri: 'package-root:example_pkg/example',
      ),
    );
    expect(rootResult.kind, CockpitPackageUriEntryKind.directory);
    expect(rootResult.contentKind, CockpitPackageUriContentKind.directory);
    expect(rootResult.entryCount, 1);
    expect(
      rootResult.entries.single.path,
      '/deps/example_pkg/example/demo.dart',
    );
  });

  test('truncates large text previews and returns binary metadata', () async {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/workspace/.dart_tool/package_config.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode(<String, Object?>{
          'configVersion': 2,
          'packages': <Map<String, Object?>>[
            <String, Object?>{
              'name': 'example_pkg',
              'rootUri': 'file:///deps/example_pkg/',
              'packageUri': 'lib/',
              'languageVersion': '3.5',
            },
          ],
        }),
      );
    fileSystem.file('/deps/example_pkg/lib/large.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync(List<String>.filled(5000, 'x').join());
    fileSystem.file('/deps/example_pkg/assets/icon.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47, 0x00]);

    final service = CockpitReadPackageUrisService(
      fileSystem: LocalCockpitFileSystem(fileSystem: fileSystem),
    );

    final textResult = await service.read(
      const CockpitReadPackageUrisRequest(
        workspaceRoot: '/workspace',
        uri: 'package-root:example_pkg/lib/large.txt',
      ),
    );
    expect(textResult.preview, isNotNull);
    expect(textResult.preview!.length, lessThan(5000));
    expect(textResult.truncated, isTrue);
    expect(textResult.totalBytes, greaterThan(4000));

    final binaryResult = await service.read(
      const CockpitReadPackageUrisRequest(
        workspaceRoot: '/workspace',
        uri: 'package-root:example_pkg/assets/icon.png',
      ),
    );
    expect(binaryResult.contentKind, CockpitPackageUriContentKind.image);
    expect(binaryResult.mediaType, 'image/png');
    expect(binaryResult.preview, contains('Binary content'));
  });
}
