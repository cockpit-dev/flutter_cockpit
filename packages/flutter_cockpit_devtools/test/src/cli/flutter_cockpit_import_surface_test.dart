import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'package:flutter_cockpit/flutter_cockpit.dart stays pure Dart importable',
    () async {
      final packageDir = _resolvePackageDir();
      final fixturePath = p.join(
        packageDir,
        'test',
        'src',
        'cli',
        'flutter_cockpit_import_surface_fixture.dart',
      );

      final result = await Process.run(
          Platform.resolvedExecutable,
          <String>[
            fixturePath,
          ],
          workingDirectory: packageDir);

      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
      );
    },
  );
}

String _resolvePackageDir() {
  final currentDir = Directory.current.path;
  final packageDir = p.join(currentDir, 'packages', 'flutter_cockpit_devtools');
  if (Directory(packageDir).existsSync()) {
    return packageDir;
  }
  return currentDir;
}
