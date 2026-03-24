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
    final runtimeReadme = File(
      'packages/flutter_cockpit/README.md',
    ).readAsStringSync();
    final devtoolsReadme = File(
      'packages/flutter_cockpit_devtools/README.md',
    ).readAsStringSync();

    expect(runtimeReadme, contains('# flutter_cockpit'));
    expect(runtimeReadme, contains('flutter_cockpit: ^1.0.0'));
    expect(
      runtimeReadme,
      contains("package:flutter_cockpit/flutter_cockpit.dart"),
    );
    expect(
      runtimeReadme,
      contains("package:flutter_cockpit/flutter_cockpit_flutter.dart"),
    );
    expect(runtimeReadme, isNot(contains('flutter_pilot')));

    expect(devtoolsReadme, contains('# flutter_cockpit_devtools'));
    expect(devtoolsReadme, contains('flutter_cockpit_devtools: ^1.0.0'));
    expect(
      devtoolsReadme,
      contains('dart run flutter_cockpit_devtools:flutter_cockpit_devtools'),
    );
    expect(
      devtoolsReadme,
      contains('dart run flutter_cockpit_devtools:flutter_cockpit_mcp'),
    );
    expect(devtoolsReadme, isNot(contains('flutter_pilot_devtools')));
    expect(devtoolsReadme, isNot(contains('flutter_pilot')));
  });
}
