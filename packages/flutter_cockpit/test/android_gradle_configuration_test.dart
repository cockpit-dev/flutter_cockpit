import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('Android plugin uses Flutter built-in Kotlin wiring', () {
    final buildFile = File('android/build.gradle');
    expect(buildFile.existsSync(), isTrue);

    final source = buildFile.readAsStringSync();
    expect(source, isNot(contains('apply plugin: "kotlin-android"')));
    expect(
      source,
      isNot(contains('org.jetbrains.kotlin:kotlin-gradle-plugin')),
    );
    expect(source, contains('kotlin {'));
    expect(source, contains('compilerOptions'));
    expect(source, contains('JvmTarget.JVM_17'));
  });
}
