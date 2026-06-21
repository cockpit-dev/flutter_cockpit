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
}

File _packageFile(String relativePath) {
  final workspaceFile = File('packages/flutter_cockpit/$relativePath');
  if (workspaceFile.existsSync()) {
    return workspaceFile;
  }
  return File(relativePath);
}
