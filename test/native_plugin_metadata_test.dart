import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.path;

  test('runtime pubspec exposes only the non-invasive web plugin', () {
    final pubspec = File(
      '$root/packages/flutter_cockpit/pubspec.yaml',
    ).readAsStringSync();

    expect(pubspec, contains('web:'));
    expect(pubspec, contains('pluginClass: FlutterCockpitWeb'));
    expect(pubspec, contains('fileName: src/web/flutter_cockpit_web.dart'));
    expect(
      pubspec,
      isNot(
        matches(
          RegExp(
            r'^\s+(android|ios|macos|linux|windows):\s*$',
            multiLine: true,
          ),
        ),
      ),
      reason:
          'The runtime must not auto-register native host plugins from a development-only dependency.',
    );
  });

  test('native plugin sources use flutter_cockpit channel names', () {
    final androidPlugin = File(
      '$root/packages/flutter_cockpit/android/src/main/kotlin/dev/cockpit/flutter_cockpit/FlutterCockpitPlugin.kt',
    );
    final iosPlugin = File(
      '$root/packages/flutter_cockpit/ios/flutter_cockpit/Sources/flutter_cockpit/FlutterCockpitPlugin.swift',
    );
    final macosPlugin = File(
      '$root/packages/flutter_cockpit/macos/flutter_cockpit/Sources/flutter_cockpit/FlutterCockpitPlugin.swift',
    );
    final linuxPlugin = File(
      '$root/packages/flutter_cockpit/linux/flutter_cockpit_plugin.cc',
    );

    expect(androidPlugin.existsSync(), isTrue);
    expect(iosPlugin.existsSync(), isTrue);
    expect(macosPlugin.existsSync(), isTrue);
    expect(linuxPlugin.existsSync(), isTrue);

    final androidSource = androidPlugin.readAsStringSync();
    final iosSource = iosPlugin.readAsStringSync();
    final macosSource = macosPlugin.readAsStringSync();
    final linuxSource = linuxPlugin.readAsStringSync();

    expect(androidSource, contains('dev.cockpit.flutter_cockpit/capture'));
    expect(androidSource, contains('dev.cockpit.flutter_cockpit/recording'));
    expect(iosSource, contains('dev.cockpit.flutter_cockpit/capture'));
    expect(iosSource, contains('dev.cockpit.flutter_cockpit/recording'));
    expect(macosSource, contains('dev.cockpit.flutter_cockpit/capture'));
    expect(macosSource, contains('dev.cockpit.flutter_cockpit/recording'));
    expect(linuxSource, contains('dev.cockpit.flutter_cockpit/capture'));
    expect(linuxSource, contains('dev.cockpit.flutter_cockpit/recording'));
  });

  test('native package metadata uses flutter_cockpit names', () {
    final podspec = File(
      '$root/packages/flutter_cockpit/ios/flutter_cockpit.podspec',
    ).readAsStringSync();
    final macosPodspec = File(
      '$root/packages/flutter_cockpit/macos/flutter_cockpit.podspec',
    ).readAsStringSync();
    final manifest = File(
      '$root/packages/flutter_cockpit/android/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final androidGradle = File(
      '$root/packages/flutter_cockpit/android/build.gradle',
    ).readAsStringSync();
    final iosPackage = File(
      '$root/packages/flutter_cockpit/ios/flutter_cockpit/Package.swift',
    ).readAsStringSync();
    final macosPackage = File(
      '$root/packages/flutter_cockpit/macos/flutter_cockpit/Package.swift',
    ).readAsStringSync();

    expect(podspec, contains("s.name             = 'flutter_cockpit'"));
    expect(podspec, contains('flutter_cockpit.'));
    expect(podspec, contains('flutter_cockpit/Sources/flutter_cockpit'));
    expect(macosPodspec, contains("s.name             = 'flutter_cockpit'"));
    expect(macosPodspec, contains('flutter_cockpit'));
    expect(macosPodspec, contains('flutter_cockpit/Sources/flutter_cockpit'));
    expect(iosPackage, contains('name: "flutter_cockpit"'));
    expect(iosPackage, contains('.iOS("13.0")'));
    expect(macosPackage, contains('name: "flutter_cockpit"'));
    expect(macosPackage, contains('.macOS("10.15")'));
    expect(manifest, contains('package="dev.cockpit.flutter_cockpit"'));
    expect(
      androidGradle,
      contains('namespace = "dev.cockpit.flutter_cockpit"'),
    );
    expect(androidGradle, isNot(contains('agpMajor < 9')));
    expect(androidGradle, isNot(contains('kotlin-gradle-plugin')));
    expect(androidGradle, contains('compilerOptions'));
  });
}
