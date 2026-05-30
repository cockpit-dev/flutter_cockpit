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
    expect(demoPubspec, contains('drift: ">=2.29.0 <2.30.0"'));
    expect(demoPubspec, contains('drift_flutter: ">=0.2.7 <0.2.8"'));
    expect(demoPubspec, contains('drift_dev: ">=2.29.0 <2.30.0"'));
    expect(demoPubspec, contains('sqlite3: ">=2.9.4 <3.0.0"'));
    expect(demoPubspec, contains('sqlite3_flutter_libs: ">=0.5.42 <0.6.0"'));
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
