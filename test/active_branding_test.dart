import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.absolute.path;

  test('root README uses flutter_cockpit branding', () {
    final readme = File('$root/README.md').readAsStringSync();

    expect(readme, contains('# flutter_cockpit'));
    expect(readme, contains('packages/flutter_cockpit'));
    expect(readme, contains('skills/flutter-cockpit'));
    expect(readme, isNot(contains('packages/flutter_pilot`')));
    expect(readme, isNot(contains('skills/flutter-pilot')));
  });

  test('active skill assets use flutter_cockpit branding and paths', () {
    final skillDir = Directory('$root/skills/flutter-cockpit');
    final legacySkillDir = Directory('$root/skills/flutter-pilot');
    final skill = File(
      '$root/skills/flutter-cockpit/SKILL.md',
    ).readAsStringSync();
    final contract = File(
      '$root/docs/contracts/flutter-cockpit-skill-contract.md',
    ).readAsStringSync();

    expect(skillDir.existsSync(), isTrue);
    expect(legacySkillDir.existsSync(), isFalse);
    expect(skill, contains('name: flutter-cockpit'));
    expect(skill, contains('# Flutter Cockpit'));
    expect(skill, isNot(contains('name: flutter-pilot')));
    expect(contract, contains('# Flutter Cockpit Skill Contract'));
    expect(contract, isNot(contains('`flutter-pilot` skill')));
  });

  test('active docs and launchers use flutter_cockpit dart defines', () {
    final files = <String>[
      'README.md',
      'README.zh-CN.md',
      'packages/flutter_cockpit/README.md',
      'packages/flutter_cockpit/README.zh-CN.md',
      'skills/flutter-cockpit/SKILL.md',
      'skills/flutter-cockpit/examples/flutter-app-setup.md',
      'packages/flutter_cockpit/lib/src/remote/cockpit_remote_session_configuration.dart',
      'packages/flutter_cockpit/lib/src/runtime/cockpit_runtime_environment.dart',
      'packages/flutter_cockpit_devtools/lib/src/development/cockpit_development_session_machine_launcher.dart',
      'packages/flutter_cockpit_devtools/lib/src/session/cockpit_android_remote_session_launcher.dart',
      'packages/flutter_cockpit_devtools/lib/src/session/cockpit_ios_physical_remote_session_launcher.dart',
      'packages/flutter_cockpit_devtools/lib/src/session/cockpit_ios_simulator_remote_session_launcher.dart',
      'packages/flutter_cockpit_devtools/lib/src/session/cockpit_linux_remote_session_launcher.dart',
      'packages/flutter_cockpit_devtools/lib/src/session/cockpit_macos_remote_session_launcher.dart',
      'packages/flutter_cockpit_devtools/lib/src/session/cockpit_windows_remote_session_launcher.dart',
    ];

    for (final relativePath in files) {
      final content = File('$root/$relativePath').readAsStringSync();
      expect(
        content,
        isNot(contains('FLUTTER_PILOT')),
        reason: '$relativePath still exposes legacy dart-define branding.',
      );
    }

    final runtimeConfig = File(
      '$root/packages/flutter_cockpit/lib/src/remote/cockpit_remote_session_configuration.dart',
    ).readAsStringSync();
    expect(runtimeConfig, contains('FLUTTER_COCKPIT_REMOTE_ENABLED'));
    expect(runtimeConfig, contains('FLUTTER_COCKPIT_REMOTE_HOST'));
    expect(runtimeConfig, contains('FLUTTER_COCKPIT_REMOTE_PORT'));
    expect(runtimeConfig, contains('FLUTTER_COCKPIT_REMOTE_ROUTE_PREFIX'));

    final runtimeEnvironment = File(
      '$root/packages/flutter_cockpit/lib/src/runtime/cockpit_runtime_environment.dart',
    ).readAsStringSync();
    expect(runtimeEnvironment, contains('FLUTTER_COCKPIT_FLUTTER_VERSION'));
  });

  test('active package trees do not keep legacy flutter_pilot filenames', () {
    final packageRoots = <Directory>[
      Directory('$root/packages/flutter_cockpit'),
      Directory('$root/packages/flutter_cockpit_devtools'),
    ];

    final legacyPaths = packageRoots
        .expand((directory) => directory.listSync(recursive: true))
        .whereType<FileSystemEntity>()
        .map((entity) => _relativePath(entity.absolute.path, root))
        .where(
          (path) =>
              path.contains('flutter_pilot') || path.contains('flutter-pilot'),
        )
        .toList(growable: false);

    expect(legacyPaths, isEmpty);
  });

  test('root readmes teach low-token app-first workflow', () {
    final readme = File('$root/README.md').readAsStringSync();
    final readmeZh = File('$root/README.zh-CN.md').readAsStringSync();

    expect(readme, contains('app.json'));
    expect(readme, contains('--output-format json'));
    expect(readme, contains('jq'));
    expect(readme, contains('--command-file'));
    expect(readme, contains('lower camel case keys'));
    expect(readme, isNot(contains('--output-json')));
    expect(readme, isNot(contains('--output-ai')));

    expect(readmeZh, contains('app.json'));
    expect(readmeZh, contains('--output-format json'));
    expect(readmeZh, contains('jq'));
    expect(readmeZh, contains('--command-file'));
    expect(readmeZh, contains('lower camel case'));
    expect(readmeZh, isNot(contains('--output-json')));
    expect(readmeZh, isNot(contains('--output-ai')));
  });

  test('devtools readmes keep output path and output format separate', () {
    final readme = File(
      '$root/packages/flutter_cockpit_devtools/README.md',
    ).readAsStringSync();
    final readmeZh = File(
      '$root/packages/flutter_cockpit_devtools/README.zh-CN.md',
    ).readAsStringSync();
    final runtimeLoopWorkflow = File(
      '$root/.github/workflows/runtime-loop.yml',
    ).readAsStringSync();

    for (final content in <String>[readme, readmeZh]) {
      expect(content, contains('--output <path>'));
      expect(content, contains('--output-format json'));
      expect(content, contains('--stdout-format json'));
      expect(content, isNot(contains('--output-json')));
      expect(content, isNot(contains('--output-ai')));
    }

    expect(runtimeLoopWorkflow, contains('--output-format json'));
    expect(runtimeLoopWorkflow, isNot(contains('--output-json')));
    expect(runtimeLoopWorkflow, isNot(contains('--output-ai')));
  });

  test('tracked text files do not keep TODO or FIXME markers', () {
    final trackedFilesResult = Process.runSync(
      'git',
      const <String>['ls-files'],
      workingDirectory: root,
    );

    expect(trackedFilesResult.exitCode, 0);

    final offenders = <String>[];
    for (final relativePath in (trackedFilesResult.stdout as String)
        .split('\n')
        .where((path) => path.trim().isNotEmpty)
        .where(_isScannableTextFile)) {
      final file = File('$root/$relativePath');
      if (!file.existsSync()) {
        continue;
      }
      final content = _tryReadUtf8Text(file);
      if (content == null) {
        continue;
      }
      if (RegExp(r'\b(?:TODO|FIXME):').hasMatch(content)) {
        offenders.add(relativePath);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Tracked text files still contain TODO/FIXME markers:\n'
          '${offenders.join('\n')}',
    );
  });
}

String _relativePath(String absolutePath, String root) {
  final normalizedRoot = root.replaceAll('\\', '/');
  final normalizedPath = absolutePath.replaceAll('\\', '/');
  if (normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  return normalizedPath;
}

bool _isScannableTextFile(String relativePath) {
  if (relativePath.endsWith('.png') ||
      relativePath.endsWith('.jpg') ||
      relativePath.endsWith('.jpeg') ||
      relativePath.endsWith('.gif') ||
      relativePath.endsWith('.webp') ||
      relativePath.endsWith('.ttf') ||
      relativePath.endsWith('.otf') ||
      relativePath.endsWith('.jar') ||
      relativePath.endsWith('.so') ||
      relativePath.endsWith('.dll') ||
      relativePath.endsWith('.dylib') ||
      relativePath.endsWith('.ico') ||
      relativePath.endsWith('.icns')) {
    return false;
  }
  return true;
}

String? _tryReadUtf8Text(File file) {
  try {
    return file.readAsStringSync();
  } on FileSystemException {
    return null;
  }
}
