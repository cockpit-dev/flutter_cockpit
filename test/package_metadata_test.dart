import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('published packages use the Cockpit 2.0 dependency graph', () {
    final runtimePubspec = File(
      'packages/flutter_cockpit/pubspec.yaml',
    ).readAsStringSync();
    final protocolPubspec = File(
      'packages/cockpit_protocol/pubspec.yaml',
    ).readAsStringSync();
    final devtoolsPubspec = File(
      'packages/cockpit/pubspec.yaml',
    ).readAsStringSync();
    final runtimeVersion = _readPackageVersion('packages/flutter_cockpit');
    final protocolVersion = _readPackageVersion('packages/cockpit_protocol');
    final devtoolsVersion = _readPackageVersion('packages/cockpit');

    expect(runtimePubspec, contains('name: flutter_cockpit'));
    expect(runtimePubspec, isNot(contains('name: flutter_pilot')));
    expect(protocolPubspec, contains('name: cockpit_protocol'));
    expect(devtoolsPubspec, contains('name: cockpit'));
    expect(runtimeVersion, '2.0.0');
    expect(protocolVersion, '2.0.0');
    expect(devtoolsVersion, '2.0.0');
    expect(runtimePubspec, contains('cockpit_protocol: ^$protocolVersion'));
    expect(devtoolsPubspec, contains('cockpit_protocol: ^$protocolVersion'));
    expect(runtimePubspec, isNot(contains('flutter_cockpit_protocol:')));
    expect(devtoolsPubspec, isNot(contains('flutter_cockpit_protocol:')));
    expect(
      devtoolsPubspec,
      isNot(contains('flutter_cockpit: ^$runtimeVersion')),
    );
    expect(
      devtoolsPubspec,
      isNot(contains('flutter:\n    sdk: flutter')),
      reason: 'The hosted cockpit executable must support pub global run.',
    );
    expect(devtoolsPubspec, contains('dart_mcp: ^0.5.2'));
    expect(devtoolsPubspec, isNot(contains('flutter_pilot: ^1.0.0')));
  });

  test('supported Flutter floor matches package, tooling, and CI bounds', () {
    final workspacePubspec = File('pubspec.yaml').readAsStringSync();
    final workspaceLockfile = File('pubspec.lock').readAsStringSync();
    final protocolPubspec = File(
      'packages/cockpit_protocol/pubspec.yaml',
    ).readAsStringSync();
    final runtimePubspec = File(
      'packages/flutter_cockpit/pubspec.yaml',
    ).readAsStringSync();
    final devtoolsPubspec = File(
      'packages/cockpit/pubspec.yaml',
    ).readAsStringSync();
    final demoPubspec = File(
      'examples/cockpit_demo/pubspec.yaml',
    ).readAsStringSync();
    final shellPubspec = File(
      'examples/cockpit_demo/cockpit/pubspec.yaml',
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
      'packages/cockpit/README.md',
    ).readAsStringSync();
    final devtoolsReadmeZh = File(
      'packages/cockpit/README.zh-CN.md',
    ).readAsStringSync();
    final runtimeLoop = File(
      '.github/workflows/runtime-loop.yml',
    ).readAsStringSync();
    final devtoolsVersion = _readPackageVersion('packages/cockpit');

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
      protocolPubspec,
      runtimePubspec,
      devtoolsPubspec,
      demoPubspec,
      shellPubspec,
    ]) {
      expect(pubspec, contains("sdk: '>=3.8.0 <4.0.0'"));
      expect(pubspec, isNot(contains("sdk: '>=3.5.0 <4.0.0'")));
      expect(pubspec, isNot(contains("sdk: '>=3.6.0 <4.0.0'")));
      expect(pubspec, isNot(contains("sdk: '>=3.7.0 <4.0.0'")));
    }
    expect(runtimePubspec, contains("flutter: '>=3.32.0'"));
    expect(demoPubspec, contains("flutter: '>=3.32.0'"));
    expect(shellPubspec, contains("flutter: '>=3.32.0'"));
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
    expect(protocolPubspec, contains('lints: ^6.1.0'));
    expect(
      workspacePubspec,
      contains('melos: 6.3.3'),
      reason:
          'melos 7.7.0 requires Dart 3.9+, but this package supports Dart 3.8.',
    );
    expect(runtimePubspec, contains('web_socket_channel: ^3.0.3'));
    expect(runtimePubspec, contains('flutter_lints: ^6.0.0'));
    expect(protocolPubspec, contains('collection: ^1.18.0'));
    expect(devtoolsPubspec, contains('lints: ^6.1.0'));
    expect(demoPubspec, contains('flutter_lints: ^6.0.0'));
    expect(devtoolsPubspec, contains('dart_mcp: ^0.5.2'));
    expect(shellPubspec, contains('cockpit: ^$devtoolsVersion'));
    expect(shellPubspec, contains('flutter_cockpit:'));
    expect(shellPubspec, contains('integration_test:'));
    expect(demoPubspec, isNot(contains('flutter_cockpit:')));
    expect(demoPubspec, isNot(contains('cockpit:')));
    expect(demoPubspec, isNot(contains('integration_test:')));
    expect(
      demoPubspec,
      contains('drift: ">=2.29.0 <2.30.0"'),
      reason:
          'drift 2.30+ pulls analyzer 8.x constraints that do not solve '
          'with Flutter 3.32 flutter_test/test_api pins.',
    );
    expect(demoPubspec, contains('drift_flutter: ">=0.2.7 <0.2.8"'));
    expect(
      demoPubspec,
      contains('drift_dev: ">=2.29.0 <2.30.0"'),
      reason:
          'drift_dev 2.30+ requires analyzer >=8.1, but Flutter 3.32 '
          'resolves test 1.25.15 with analyzer <8.0.',
    );
    expect(demoPubspec, contains('sqlite3: ">=2.9.4 <3.0.0"'));
    expect(demoPubspec, contains('sqlite3_flutter_libs: ">=0.5.42 <0.6.0"'));
    expect(workspacePubspec, contains("test: '>=1.25.15 <2.0.0'"));
    expect(runtimePubspec, contains("test: '>=1.25.15 <2.0.0'"));
    expect(devtoolsPubspec, contains("test: '>=1.25.15 <2.0.0'"));
  });

  test('package readmes teach flutter_cockpit installation and usage', () {
    final runtimeVersion = _readPackageVersion('packages/flutter_cockpit');
    final devtoolsVersion = _readPackageVersion('packages/cockpit');
    final runtimeReadme = File(
      'packages/flutter_cockpit/README.md',
    ).readAsStringSync();
    final runtimeReadmeZh = File(
      'packages/flutter_cockpit/README.zh-CN.md',
    ).readAsStringSync();
    final devtoolsReadme = File(
      'packages/cockpit/README.md',
    ).readAsStringSync();
    final devtoolsReadmeZh = File(
      'packages/cockpit/README.zh-CN.md',
    ).readAsStringSync();

    expect(runtimeReadme, contains('# flutter_cockpit'));
    expect(runtimeReadme, contains('flutter_cockpit: ^$runtimeVersion'));
    expect(
      runtimeReadme,
      contains("package:flutter_cockpit/flutter_cockpit_flutter.dart"),
    );
    expect(runtimeReadme, contains('cd cockpit'));
    expect(runtimeReadme, contains('--target main.dart'));
    expect(runtimeReadme, contains('https://pub.dev/packages/cockpit'));
    expect(runtimeReadme, isNot(contains('flutter_pilot')));

    expect(devtoolsReadme, contains('# cockpit'));
    expect(devtoolsReadme, contains('cockpit: ^$devtoolsVersion'));
    expect(devtoolsReadme, contains('dart run cockpit'));
    expect(devtoolsReadme, contains('serve-mcp'));
    expect(devtoolsReadme, contains('read-task-bundle-summary'));
    expect(devtoolsReadme, contains('read_task_bundle_summary'));
    expect(devtoolsReadme, isNot(contains('flutter_pilot_devtools')));
    expect(devtoolsReadme, isNot(contains('flutter_pilot')));

    expect(runtimeReadmeZh, contains('flutter_cockpit: ^$runtimeVersion'));
    expect(runtimeReadmeZh, contains('https://pub.dev/packages/cockpit'));
    expect(devtoolsReadmeZh, contains('cockpit: ^$devtoolsVersion'));
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

  test('demo keeps cockpit integration out of production lib code', () {
    final productionPubspec = File(
      'examples/cockpit_demo/pubspec.yaml',
    ).readAsStringSync();
    final shellPubspec = File(
      'examples/cockpit_demo/cockpit/pubspec.yaml',
    ).readAsStringSync();
    final devDependenciesIndex = shellPubspec.indexOf('dev_dependencies:');

    expect(devDependenciesIndex, isNonNegative);
    expect(
      shellPubspec.indexOf('  flutter_cockpit:'),
      greaterThan(devDependenciesIndex),
    );
    expect(
      shellPubspec.indexOf('  cockpit:'),
      greaterThan(devDependenciesIndex),
    );
    expect(
      shellPubspec.indexOf('  integration_test:'),
      greaterThan(devDependenciesIndex),
    );
    expect(productionPubspec, isNot(contains('flutter_cockpit:')));
    expect(productionPubspec, isNot(contains('cockpit:')));
    expect(productionPubspec, isNot(contains('integration_test:')));

    for (final file
        in Directory('examples/cockpit_demo/lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('package:flutter_cockpit/')),
        reason: '${file.path} must remain production-only.',
      );
      expect(
        source,
        isNot(contains('package:cockpit/')),
        reason: '${file.path} must remain production-only.',
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
      'packages/cockpit/README.md',
    ).readAsStringSync();
    final devtoolsReadmeZh = File(
      'packages/cockpit/README.zh-CN.md',
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
        'https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/cockpit/README.zh-CN.md',
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
        'https://github.com/cockpit-dev/flutter_cockpit/blob/main/packages/cockpit/README.md',
      ),
    );
  });

  test('published packages exclude local-only editor metadata', () {
    for (final packageDir in <String>[
      'packages/flutter_cockpit',
      'packages/cockpit',
    ]) {
      final pubignore = File('$packageDir/.pubignore').readAsStringSync();
      expect(pubignore, contains('*.iml'));
    }
  });

  test('published packages include package-local examples', () {
    final runtimeExample = File('packages/flutter_cockpit/example/main.dart');
    final devtoolsExample = File('packages/cockpit/example/main.dart');

    expect(runtimeExample.existsSync(), isTrue);
    expect(devtoolsExample.existsSync(), isTrue);

    final runtimeSource = runtimeExample.readAsStringSync();
    final devtoolsSource = devtoolsExample.readAsStringSync();

    expect(
      runtimeSource,
      contains("package:flutter_cockpit/flutter_cockpit_flutter.dart"),
    );
    expect(
      runtimeSource,
      contains('CockpitRemoteSessionConfiguration.resolveFromEnvironment'),
    );
    expect(runtimeSource, contains('FlutterCockpit.navigatorObserver'));
    expect(runtimeSource, contains('FlutterCockpit.setCurrentRouteName'));

    expect(devtoolsSource, contains("package:cockpit/cockpit.dart"));
    expect(devtoolsSource, contains('CockpitCommandRunner'));
    expect(devtoolsSource, contains('read-system-capabilities'));
    expect(devtoolsSource, contains('capture-screenshot'));
  });

  test(
    'pure Dart runtime export does not expose dart:io implementation files',
    () {
      final exportGraph = _runtimeLibraryGraph();
      expect(
        exportGraph,
        isNot(contains('src/network/cockpit_http_network_observer.dart')),
        reason:
            'package:flutter_cockpit/flutter_cockpit.dart is consumed by host '
            'tools and web model code; dart:io observers belong in the Flutter '
            'entrypoint export.',
      );
    },
  );

  test(
    'published cockpit readmes do not present pubignored tools as package commands',
    () {
      final devtoolsReadme = File(
        'packages/cockpit/README.md',
      ).readAsStringSync();
      final devtoolsReadmeZh = File(
        'packages/cockpit/README.zh-CN.md',
      ).readAsStringSync();

      for (final document in <String>[devtoolsReadme, devtoolsReadmeZh]) {
        expect(
          document,
          isNot(contains('dart run tool/verify_mcp_surface.dart')),
        );
        expect(document, contains('github.com/cockpit-dev/flutter_cockpit'));
      }
    },
  );

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
      final rootContract = File('docs/contracts/$fileName');
      final packageContract = File('packages/cockpit/doc/contracts/$fileName');
      expect(packageContract.existsSync(), isTrue);
      expect(
        packageContract.readAsBytesSync(),
        rootContract.readAsBytesSync(),
        reason:
            'MCP workspace contract resources must work from a published '
            'cockpit package with the same contract text as the monorepo root.',
      );
    }
  });

  test('flutter-cockpit skill exposes a local protocol reference', () {
    final skill = File('skills/flutter-cockpit/SKILL.md').readAsStringSync();
    final protocolReference = File(
      'skills/flutter-cockpit/references/protocol.md',
    ).readAsStringSync();

    expect(skill, contains('references/protocol.md'));
    expect(protocolReference, contains('## Reference Contract'));
    expect(protocolReference, contains('cockpit://workspace/protocol'));
    expect(
      protocolReference,
      contains('docs/contracts/flutter-cockpit-protocol.md'),
    );
    expect(protocolReference, contains('packages/cockpit/doc/contracts/'));
    expect(protocolReference, contains('Load only the contract'));
  });

  test('devtools package readmes expose workflow protocol references', () {
    final devtoolsReadme = File(
      'packages/cockpit/README.md',
    ).readAsStringSync();
    final devtoolsReadmeZh = File(
      'packages/cockpit/README.zh-CN.md',
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
    final example = File('packages/cockpit/example/mcp_config.json');
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

  test('tracked repository markdown local links resolve', () {
    final missingLinks = _localMarkdownLinkIssues();
    expect(missingLinks, isEmpty, reason: missingLinks.join('\n'));
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

Set<String> _runtimeLibraryGraph() {
  final visited = <String>{};
  final pending = <String>['packages/flutter_cockpit/lib/flutter_cockpit.dart'];
  while (pending.isNotEmpty) {
    final path = pending.removeLast();
    if (!visited.add(path)) {
      continue;
    }
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    final source = file.readAsStringSync();
    for (final match in RegExp(
      r"(?:export|import)\s+'([^']+)';",
    ).allMatches(source)) {
      final rawTarget = match.group(1)!;
      if (rawTarget.startsWith('dart:') || rawTarget.startsWith('package:')) {
        continue;
      }
      if (!rawTarget.endsWith('.dart')) {
        continue;
      }
      final resolved = rawTarget.startsWith('src/')
          ? 'packages/flutter_cockpit/lib/$rawTarget'
          : _normalizePackagePath('${file.parent.path}/$rawTarget');
      pending.add(resolved);
    }
  }
  return visited
      .map((path) => path.replaceFirst('packages/flutter_cockpit/lib/', ''))
      .toSet();
}

String _normalizePackagePath(String path) {
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') {
      continue;
    }
    if (segment == '..') {
      if (segments.isNotEmpty) {
        segments.removeLast();
      }
      continue;
    }
    segments.add(segment);
  }
  return segments.join('/');
}

List<String> _localMarkdownLinkIssues() {
  final files = _trackedMarkdownFiles();
  final missing = <String>[];
  for (final path in files) {
    final markdown = _stripMarkdownCode(File(path).readAsStringSync());
    final linkPattern = RegExp(r'!?\[[^\]]+\]\(([^)\s]+)(?:\s+"[^"]*")?\)');
    for (final match in linkPattern.allMatches(markdown)) {
      final rawLink = match.group(1)!.trim();
      if (_isExternalOrAnchorLink(rawLink)) {
        continue;
      }
      final targetPath = Uri.decodeComponent(rawLink).split('#').first;
      if (targetPath.isEmpty) {
        continue;
      }
      final resolvedPath = targetPath.startsWith('/')
          ? targetPath.substring(1)
          : '${File(path).parent.path}/$targetPath';
      if (!File(resolvedPath).existsSync() &&
          !Directory(resolvedPath).existsSync()) {
        missing.add('$path -> $rawLink ($resolvedPath)');
      }
    }
  }
  return missing;
}

List<String> _trackedMarkdownFiles() {
  final result = Process.runSync('git', <String>['ls-files', '*.md']);
  if (result.exitCode != 0) {
    throw StateError('Unable to list tracked markdown files: ${result.stderr}');
  }
  final tracked = (result.stdout as String)
      .split('\n')
      .where((path) => path.endsWith('.md'))
      .where((path) => !path.split('/').contains('third'))
      .where((path) => File(path).existsSync())
      .toList();
  final shellValidationReadme =
      'examples/cockpit_demo/cockpit/validation/README.md';
  if (File(shellValidationReadme).existsSync()) {
    tracked.add(shellValidationReadme);
  }
  return tracked;
}

String _stripMarkdownCode(String markdown) {
  final withoutFencedBlocks = markdown.replaceAll(
    RegExp(r'```[\s\S]*?```'),
    '',
  );
  return withoutFencedBlocks.replaceAll(RegExp(r'`[^`\n]*`'), '');
}

bool _isExternalOrAnchorLink(String link) {
  if (link.startsWith('#')) {
    return true;
  }
  return RegExp(r'^[a-z][a-z0-9+.-]*:').hasMatch(link);
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
