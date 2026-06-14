import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('runtime package does not auto-register native host plugins', () {
    final pubspecFile = _packageFile('pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue);

    final source = pubspecFile.readAsStringSync();
    expect(source, contains('plugin:'));
    expect(source, contains('web:'));
    expect(
      source,
      isNot(
        matches(
          RegExp(
            r'^\s+(android|ios|macos|linux|windows):\s*$',
            multiLine: true,
          ),
        ),
      ),
      reason: 'Cockpit must not leak native plugins into host release bundles.',
    );
  });
}

File _packageFile(String relativePath) {
  final workspaceFile = File('packages/flutter_cockpit/$relativePath');
  if (workspaceFile.existsSync()) {
    return workspaceFile;
  }
  return File(relativePath);
}
