import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

Future<void> main() async {
  final projectDir = Directory.current.path;
  final webDir = Directory(p.join(projectDir, 'web'));
  if (!webDir.existsSync()) {
    throw StateError('web directory is missing under $projectDir');
  }

  await _compileWorker(projectDir: projectDir);
  await _copySqliteWasm(projectDir: projectDir);
}

Future<void> _compileWorker({required String projectDir}) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    <String>[
      'compile',
      'js',
      'web/drift_worker.dart',
      '-O4',
      '-o',
      'web/drift_worker.js',
    ],
    workingDirectory: projectDir,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'Failed to compile drift worker: ${result.stderr}\n${result.stdout}',
    );
  }
}

Future<void> _copySqliteWasm({required String projectDir}) async {
  final driftLibrary = await Isolate.resolvePackageUri(
    Uri.parse('package:drift/wasm.dart'),
  );
  if (driftLibrary == null) {
    throw StateError('Unable to resolve package:drift/wasm.dart');
  }
  final driftPackageDir = p.normalize(
    p.join(p.dirname(driftLibrary.toFilePath()), '..'),
  );
  final source = File(
    p.join(driftPackageDir, 'extension', 'devtools', 'build', 'sqlite3.wasm'),
  );
  if (!source.existsSync()) {
    throw StateError('sqlite3.wasm was not found at ${source.path}');
  }
  final destination = File(p.join(projectDir, 'web', 'sqlite3.wasm'));
  await destination.parent.create(recursive: true);
  await source.copy(destination.path);
}
