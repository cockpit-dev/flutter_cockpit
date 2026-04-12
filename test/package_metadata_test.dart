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
    expect(
      runtimeReadme,
      contains('flutter run -t cockpit/main.dart'),
    );
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
    expect(
      devtoolsReadme,
      contains('serve-mcp'),
    );
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
}

String _readPackageVersion(String packageDir) {
  final pubspec = File('$packageDir/pubspec.yaml').readAsStringSync();
  final match =
      RegExp(r'^version:\s+([0-9]+\.[0-9]+\.[0-9]+)$', multiLine: true)
          .firstMatch(pubspec);
  if (match == null) {
    throw StateError('Unable to read version from $packageDir/pubspec.yaml');
  }
  return match.group(1)!;
}
