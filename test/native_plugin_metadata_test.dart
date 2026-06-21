import 'dart:io';

import 'package:test/test.dart';

void main() {
  final root = Directory.current.path;

  test(
    'runtime pubspec registers app-side plugins on every Flutter platform',
    () {
      final pubspec = File(
        '$root/packages/flutter_cockpit/pubspec.yaml',
      ).readAsStringSync();

      for (final entry in <String, String>{
        'android': 'pluginClass: FlutterCockpitPlugin',
        'ios': 'pluginClass: FlutterCockpitPlugin',
        'linux': 'pluginClass: FlutterCockpitPlugin',
        'macos': 'pluginClass: FlutterCockpitPlugin',
        'windows': 'pluginClass: FlutterCockpitPluginCApi',
        'web': 'pluginClass: FlutterCockpitWeb',
      }.entries) {
        expect(
          pubspec,
          matches(RegExp('^      ${entry.key}:\\s*\$', multiLine: true)),
          reason:
              'App-window capture and recording fallbacks require the runtime plugin to register on ${entry.key}.',
        );
        expect(pubspec, contains(entry.value));
      }
      expect(pubspec, contains('package: dev.cockpit.flutter_cockpit'));
      expect(pubspec, contains('web:'));
      expect(pubspec, contains('pluginClass: FlutterCockpitWeb'));
      expect(pubspec, contains('fileName: src/web/flutter_cockpit_web.dart'));
    },
  );

  test('example desktop generated registrants include the native runtime plugin', () {
    expect(
      File(
        '$root/examples/cockpit_demo/macos/Flutter/GeneratedPluginRegistrant.swift',
      ).readAsStringSync(),
      allOf(
        contains('import flutter_cockpit'),
        contains('FlutterCockpitPlugin.register'),
      ),
    );
    expect(
      File(
        '$root/examples/cockpit_demo/linux/flutter/generated_plugin_registrant.cc',
      ).readAsStringSync(),
      allOf(
        contains('#include <flutter_cockpit/flutter_cockpit_plugin.h>'),
        contains('flutter_cockpit_plugin_register_with_registrar'),
      ),
    );
    expect(
      File(
        '$root/examples/cockpit_demo/windows/flutter/generated_plugin_registrant.cc',
      ).readAsStringSync(),
      allOf(
        contains('#include <flutter_cockpit/flutter_cockpit_plugin_c_api.h>'),
        contains('FlutterCockpitPluginCApiRegisterWithRegistrar'),
      ),
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
