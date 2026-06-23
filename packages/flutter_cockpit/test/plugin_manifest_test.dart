import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('runtime package registers app-window plugins on every platform', () {
    final pubspecFile = _packageFile('pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue);

    final source = pubspecFile.readAsStringSync();
    expect(source, contains('plugin:'));
    for (final entry in <String, List<String>>{
      'android': <String>[
        'package: dev.cockpit.flutter_cockpit',
        'pluginClass: FlutterCockpitPlugin',
      ],
      'ios': <String>['pluginClass: FlutterCockpitPlugin'],
      'linux': <String>['pluginClass: FlutterCockpitPlugin'],
      'macos': <String>['pluginClass: FlutterCockpitPlugin'],
      'windows': <String>['pluginClass: FlutterCockpitPluginCApi'],
      'web': <String>[
        'pluginClass: FlutterCockpitWeb',
        'fileName: src/web/flutter_cockpit_web.dart',
      ],
    }.entries) {
      expect(
        source,
        matches(RegExp('^      ${entry.key}:\\s*\$', multiLine: true)),
        reason:
            'The runtime plugin must register app-window capture and recording fallbacks on ${entry.key}.',
      );
      for (final expectedLine in entry.value) {
        expect(source, contains(expectedLine), reason: entry.key);
      }
    }
  });

  test('Darwin SwiftPM packages use Flutter template-compatible metadata', () {
    final iosPackage = _packageFile(
      'ios/flutter_cockpit/Package.swift',
    ).readAsStringSync();
    final macosPackage = _packageFile(
      'macos/flutter_cockpit/Package.swift',
    ).readAsStringSync();

    expect(iosPackage, contains('name: "flutter_cockpit"'));
    expect(iosPackage, contains('.iOS("13.0")'));
    expect(iosPackage, contains('dependencies: []'));
    expect(iosPackage, contains('.process("PrivacyInfo.xcprivacy")'));
    expect(iosPackage, isNot(contains('FlutterFramework')));

    expect(macosPackage, contains('name: "flutter_cockpit"'));
    expect(macosPackage, contains('.macOS("10.15")'));
    expect(macosPackage, contains('dependencies: []'));
    expect(macosPackage, contains('.process("PrivacyInfo.xcprivacy")'));
    expect(macosPackage, isNot(contains('FlutterFramework')));
  });
}

File _packageFile(String relativePath) {
  final workspaceFile = File('packages/flutter_cockpit/$relativePath');
  if (workspaceFile.existsSync()) {
    return workspaceFile;
  }
  return File(relativePath);
}
