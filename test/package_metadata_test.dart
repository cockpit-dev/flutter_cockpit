import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('published package names and dependency edges use flutter_cockpit', () {
    final runtimePubspec = File(
      'packages/flutter_cockpit/pubspec.yaml',
    ).readAsStringSync();
    final devtoolsPubspec = File(
      'packages/flutter_cockpit_devtools/pubspec.yaml',
    ).readAsStringSync();

    expect(runtimePubspec, contains('name: flutter_cockpit'));
    expect(runtimePubspec, isNot(contains('name: flutter_pilot')));
    expect(devtoolsPubspec, contains('name: flutter_cockpit_devtools'));
    expect(devtoolsPubspec, contains('flutter_cockpit: ^1.0.0'));
    expect(devtoolsPubspec, isNot(contains('flutter_pilot: ^1.0.0')));
  });

  test('supported Flutter floor matches package, tooling, and CI bounds', () {
    final workspacePubspec = File('pubspec.yaml').readAsStringSync();
    final workspaceLockfile = File('pubspec.lock').readAsStringSync();
    final runtimePubspec = File(
      'packages/flutter_cockpit/pubspec.yaml',
    ).readAsStringSync();
    final devtoolsPubspec = File(
      'packages/flutter_cockpit_devtools/pubspec.yaml',
    ).readAsStringSync();
    final demoPubspec = File(
      'examples/cockpit_demo/pubspec.yaml',
    ).readAsStringSync();
    final rootReadme = File('README.md').readAsStringSync();
    final rootReadmeZh = File('README.zh-CN.md').readAsStringSync();
    final runtimeReadme = File(
      'packages/flutter_cockpit/README.md',
    ).readAsStringSync();
    final runtimeReadmeZh = File(
      'packages/flutter_cockpit/README.zh-CN.md',
    ).readAsStringSync();
    final devtoolsReadme = File(
      'packages/flutter_cockpit_devtools/README.md',
    ).readAsStringSync();
    final devtoolsReadmeZh = File(
      'packages/flutter_cockpit_devtools/README.zh-CN.md',
    ).readAsStringSync();
    final runtimeLoop = File(
      '.github/workflows/runtime-loop.yml',
    ).readAsStringSync();

    expect(
      workspacePubspec,
      contains('uses-material-design: true'),
      reason:
          'Flutter tests may use the workspace pubspec as the primary manifest; '
          'it must opt into Material Icons when the cockpit_demo workspace '
          'package does.',
    );
    expect(
      runtimePubspec,
      contains('uses-material-design: true'),
      reason:
          'Runtime package widget tests use Material Icons and may treat '
          'workspace packages as dependencies during asset assembly.',
    );
    for (final pubspec in <String>[
      workspacePubspec,
      runtimePubspec,
      devtoolsPubspec,
      demoPubspec,
    ]) {
      expect(pubspec, contains("sdk: '>=3.8.0 <4.0.0'"));
      expect(pubspec, isNot(contains("sdk: '>=3.5.0 <4.0.0'")));
      expect(pubspec, isNot(contains("sdk: '>=3.6.0 <4.0.0'")));
      expect(pubspec, isNot(contains("sdk: '>=3.7.0 <4.0.0'")));
    }
    expect(runtimePubspec, contains("flutter: '>=3.32.0'"));
    expect(demoPubspec, contains("flutter: '>=3.32.0'"));
    if (Platform.version.startsWith('3.8.')) {
      expect(workspaceLockfile, contains('dart: ">=3.8.0 <4.0.0"'));
      expect(workspaceLockfile, contains('flutter: ">=3.32.0"'));
      expect(workspaceLockfile, isNot(contains('>=3.10.0-0')));
    }
    expect(runtimeLoop, contains("FLUTTER_VERSION: '3.32.0'"));
    expect(rootReadme, contains('Flutter 3.32.0'));
    expect(rootReadme, contains('Dart 3.8.0'));
    expect(rootReadmeZh, contains('Flutter 3.32.0'));
    expect(rootReadmeZh, contains('Dart 3.8.0'));
    expect(runtimeReadme, contains('Flutter 3.32.0'));
    expect(runtimeReadmeZh, contains('Flutter 3.32.0'));
    expect(devtoolsReadme, contains('Dart 3.8.0'));
    expect(devtoolsReadme, contains('Flutter 3.32.0'));
    expect(devtoolsReadmeZh, contains('Dart 3.8.0'));
    expect(devtoolsReadmeZh, contains('Flutter 3.32.0'));
    expect(workspacePubspec, contains('lints: ^6.1.0'));
    expect(
      workspacePubspec,
      contains('melos: 6.3.3'),
      reason:
          'melos 7.7.0 requires Dart 3.9+, but this package supports Dart 3.8.',
    );
    expect(runtimePubspec, contains('web_socket_channel: ^3.0.3'));
    expect(runtimePubspec, contains('flutter_lints: ^6.0.0'));
    expect(devtoolsPubspec, contains('lints: ^6.1.0'));
    expect(demoPubspec, contains('flutter_lints: ^6.0.0'));
    expect(devtoolsPubspec, contains('dart_mcp: ^0.5.1'));
    expect(demoPubspec, contains('flutter_cockpit_devtools: ^1.0.0'));
    expect(demoPubspec, contains('drift: ^2.34.0'));
    expect(demoPubspec, contains('drift_flutter: ^0.3.0'));
    expect(demoPubspec, contains('drift_dev: ^2.34.0'));
    expect(demoPubspec, contains('sqlite3: ^3.3.3'));
    expect(demoPubspec, contains('sqlite3_flutter_libs: ^0.6.0+eol'));
    expect(workspacePubspec, contains("test: '>=1.25.15 <2.0.0'"));
    expect(runtimePubspec, contains("test: '>=1.25.15 <2.0.0'"));
    expect(devtoolsPubspec, contains("test: '>=1.25.15 <2.0.0'"));
    expect(demoPubspec, contains("test: '>=1.25.15 <2.0.0'"));
  });

  test('package readmes teach flutter_cockpit installation and usage', () {
    final runtimeVersion = _readPackageVersion('packages/flutter_cockpit');
    final devtoolsVersion = _readPackageVersion(
      'packages/flutter_cockpit_devtools',
    );
    final runtimeReadme = File(
      'packages/flutter_cockpit/README.md',
    ).readAsStringSync();
    final runtimeReadmeZh = File(
      'packages/flutter_cockpit/README.zh-CN.md',
    ).readAsStringSync();
    final devtoolsReadme = File(
      'packages/flutter_cockpit_devtools/README.md',
    ).readAsStringSync();
    final devtoolsReadmeZh = File(
      'packages/flutter_cockpit_devtools/README.zh-CN.md',
    ).readAsStringSync();

    expect(runtimeReadme, contains('# flutter_cockpit'));
    expect(runtimeReadme, contains('flutter_cockpit: ^$runtimeVersion'));
    expect(
      runtimeReadme,
      contains("package:flutter_cockpit/flutter_cockpit_flutter.dart"),
    );
    expect(runtimeReadme, contains('flutter run -t cockpit/main.dart'));
    expect(
      runtimeReadme,
      contains('https://pub.dev/packages/flutter_cockpit_devtools'),
    );
    expect(runtimeReadme, isNot(contains('flutter_pilot')));

    expect(devtoolsReadme, contains('# flutter_cockpit_devtools'));
    expect(
      devtoolsReadme,
      contains('flutter_cockpit_devtools: ^$devtoolsVersion'),
    );
    expect(
      devtoolsReadme,
      contains('dart run flutter_cockpit_devtools:flutter_cockpit_devtools'),
    );
    expect(devtoolsReadme, contains('serve-mcp'));
    expect(devtoolsReadme, contains('read-task-bundle-summary'));
    expect(devtoolsReadme, contains('read_task_bundle_summary'));
    expect(devtoolsReadme, isNot(contains('flutter_pilot_devtools')));
    expect(devtoolsReadme, isNot(contains('flutter_pilot')));

    expect(runtimeReadmeZh, contains('flutter_cockpit: ^$runtimeVersion'));
    expect(
      runtimeReadmeZh,
      contains('https://pub.dev/packages/flutter_cockpit_devtools'),
    );
    expect(
      devtoolsReadmeZh,
      contains('flutter_cockpit_devtools: ^$devtoolsVersion'),
    );
  });

  test('setup docs keep cockpit wiring outside production lib code', () {
    final rootReadme = File('README.md').readAsStringSync();
    final runtimeReadme = File(
      'packages/flutter_cockpit/README.md',
    ).readAsStringSync();
    final skill = File('skills/flutter-cockpit/SKILL.md').readAsStringSync();
    final setupExample = File(
      'skills/flutter-cockpit/examples/flutter-app-setup.md',
    ).readAsStringSync();

    for (final document in <String>[
      rootReadme,
      runtimeReadme,
      skill,
      setupExample,
    ]) {
      expect(
        document,
        contains(
          'Do not add `flutter_cockpit` imports to production `lib/` code',
        ),
      );
    }
  });

  test('agent command docs show top-level locators for tap commands', () {
    final skill = File('skills/flutter-cockpit/SKILL.md').readAsStringSync();
    final cliReference = File(
      'skills/flutter-cockpit/examples/cli-command-reference.md',
    ).readAsStringSync();
    const tapWithLocator =
        '{"commandId":"tap-settings","commandType":"tap","locator":{"text":"Settings"}';

    for (final document in <String>[skill, cliReference]) {
      expect(document, contains(tapWithLocator));
      expect(
        document,
        isNot(contains('"commandType":"tap","parameters":{"text"')),
      );
    }
  });

  test('published package readme language links target repository files', () {
    final runtimeReadme = File(
      'packages/flutter_cockpit/README.md',
    ).readAsStringSync();
    final runtimeReadmeZh = File(
      'packages/flutter_cockpit/README.zh-CN.md',
    ).readAsStringSync();
    final devtoolsReadme = File(
      'packages/flutter_cockpit_devtools/README.md',
    ).readAsStringSync();
    final devtoolsReadmeZh = File(
      'packages/flutter_cockpit_devtools/README.zh-CN.md',
    ).readAsStringSync();

    expect(runtimeReadme, isNot(contains('](README.zh-CN.md)')));
    expect(devtoolsReadme, isNot(contains('](README.zh-CN.md)')));
    expect(runtimeReadmeZh, isNot(contains('](README.md)')));
    expect(devtoolsReadmeZh, isNot(contains('](README.md)')));

    expect(
      runtimeReadme,
      contains(
        'https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/README.zh-CN.md',
      ),
    );
    expect(
      devtoolsReadme,
      contains(
        'https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit_devtools/README.zh-CN.md',
      ),
    );
    expect(
      runtimeReadmeZh,
      contains(
        'https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit/README.md',
      ),
    );
    expect(
      devtoolsReadmeZh,
      contains(
        'https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/flutter_cockpit_devtools/README.md',
      ),
    );
  });

  test('published packages exclude local-only editor metadata', () {
    for (final packageDir in <String>[
      'packages/flutter_cockpit',
      'packages/flutter_cockpit_devtools',
    ]) {
      final pubignore = File('$packageDir/.pubignore').readAsStringSync();
      expect(pubignore, contains('*.iml'));
    }
  });

  test('devtools package includes MCP contract fallback documents', () {
    final contractFiles = <String>[
      'ai-development-protocol.md',
      'flutter-cockpit-protocol.md',
      'flutter-cockpit-skill-contract.md',
      'task-run-bundle.md',
      'control-workflow-protocol.md',
      'control-workflow.schema.json',
    ];

    for (final fileName in contractFiles) {
      expect(
        File(
          'packages/flutter_cockpit_devtools/doc/contracts/$fileName',
        ).existsSync(),
        isTrue,
        reason:
            'MCP workspace contract resources must work from a published '
            'flutter_cockpit_devtools package, not only from the monorepo root.',
      );
    }
  });

  test('devtools package readmes expose workflow protocol references', () {
    final devtoolsReadme = File(
      'packages/flutter_cockpit_devtools/README.md',
    ).readAsStringSync();
    final devtoolsReadmeZh = File(
      'packages/flutter_cockpit_devtools/README.zh-CN.md',
    ).readAsStringSync();

    for (final document in <String>[devtoolsReadme, devtoolsReadmeZh]) {
      expect(document, contains('doc/contracts/ai-development-protocol.md'));
      expect(document, contains('doc/contracts/control-workflow-protocol.md'));
      expect(document, contains('doc/contracts/control-workflow.schema.json'));
      expect(document, contains('cockpit://workspace/ai-development-protocol'));
      expect(
        document,
        contains('cockpit://workspace/control-workflow-protocol'),
      );
      expect(document, contains('cockpit://workspace/control-workflow-schema'));
      expect(document, contains('run-script --script'));
    }
  });

  test('devtools package ships a copyable MCP config example', () {
    final example = File(
      'packages/flutter_cockpit_devtools/example/mcp_config.json',
    );
    expect(example.existsSync(), isTrue);
    expect(
      example.readAsStringSync(),
      allOf(
        contains('"mcpServers"'),
        contains('"flutter-cockpit"'),
        contains('"command": "dart"'),
        contains('"serve-mcp"'),
      ),
    );
  });

  test('cockpit demo web database assets match resolved dependencies', () {
    final lockfile = File('pubspec.lock').readAsStringSync();
    final depsFile = File(
      'examples/cockpit_demo/web/drift_worker.js.deps',
    ).readAsStringSync();
    final wasm = File('examples/cockpit_demo/web/sqlite3.wasm');
    final wasmHeader = wasm.readAsBytesSync().take(4).toList();

    final driftVersion = _readLockfilePackageVersion(lockfile, 'drift');
    final sqliteVersion = _readLockfilePackageVersion(lockfile, 'sqlite3');

    expect(depsFile, contains('/drift-$driftVersion/'));
    expect(depsFile, contains('/sqlite3-$sqliteVersion/'));
    expect(wasm.existsSync(), isTrue);
    expect(wasm.lengthSync(), greaterThan(512 * 1024));
    expect(wasmHeader, equals(<int>[0x00, 0x61, 0x73, 0x6d]));
  });
}

String _readPackageVersion(String packageDir) {
  final pubspec = File('$packageDir/pubspec.yaml').readAsStringSync();
  final match = RegExp(
    r'^version:\s+([0-9]+\.[0-9]+\.[0-9]+)$',
    multiLine: true,
  ).firstMatch(pubspec);
  if (match == null) {
    throw StateError('Unable to read version from $packageDir/pubspec.yaml');
  }
  return match.group(1)!;
}

String _readLockfilePackageVersion(String lockfile, String packageName) {
  final match = RegExp(
    '^  ${RegExp.escape(packageName)}:\\n'
    r'(?:    .+\n)*?'
    r'    version: "([^"]+)"',
    multiLine: true,
  ).firstMatch(lockfile);
  if (match == null) {
    throw StateError('Unable to read $packageName from pubspec.lock');
  }
  return match.group(1)!;
}
