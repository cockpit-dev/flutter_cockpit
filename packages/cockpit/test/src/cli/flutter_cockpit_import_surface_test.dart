import 'dart:io';

import 'package:cockpit/src/session/cockpit_remote_session_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test(
    'package:cockpit_protocol/cockpit_protocol.dart stays pure Dart importable',
    () async {
      final packageDir = _resolvePackageDir();
      final fixturePath = p.join(
        packageDir,
        'test',
        'src',
        'cli',
        'flutter_cockpit_import_surface_fixture.dart',
      );
      final dartExecutable = await cockpitResolveActiveDartExecutable();

      final result = await Process.run(dartExecutable, <String>[
        fixturePath,
      ], workingDirectory: packageDir);

      expect(
        result.exitCode,
        0,
        reason: 'stdout:\n${result.stdout}\n\nstderr:\n${result.stderr}',
      );
    },
  );
}

String _resolvePackageDir() {
  final currentDir = Directory.current.absolute.path;
  final candidates = <String>[
    p.join(currentDir, 'packages', 'cockpit'),
    currentDir,
  ];
  for (final candidate in candidates) {
    final pubspec = File(p.join(candidate, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      continue;
    }
    final document = loadYaml(pubspec.readAsStringSync());
    if (document is YamlMap && document['name'] == 'cockpit') {
      return p.normalize(candidate);
    }
  }
  throw StateError(
    'Unable to resolve the cockpit package from ${Directory.current.path}.',
  );
}
