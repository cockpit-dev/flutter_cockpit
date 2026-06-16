import 'package:cockpit/src/infrastructure/cockpit_sdk_environment.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CockpitSdkEnvironment', () {
    test('resolves SDK roots into platform executables', () {
      final environment =
          CockpitSdkEnvironment.fromEnvironment(<String, String>{
            'DART_ROOT': p.join('/opt', 'dart-sdk'),
            'FLUTTER_ROOT': p.join('/opt', 'flutter'),
          }, isWindows: false);

      expect(
        environment.dartExecutable,
        p.join('/opt', 'dart-sdk', 'bin', 'dart'),
      );
      expect(
        environment.flutterExecutable,
        p.join('/opt', 'flutter', 'bin', 'flutter'),
      );
    });

    test('keeps explicit executable variables ahead of root variables', () {
      final environment =
          CockpitSdkEnvironment.fromEnvironment(<String, String>{
            'DART': '/custom/dart',
            'DART_ROOT': '/ignored/dart-sdk',
            'FLUTTER_BIN': '/custom/flutter',
            'FLUTTER_ROOT': '/ignored/flutter',
          }, isWindows: false);

      expect(environment.dartExecutable, '/custom/dart');
      expect(environment.flutterExecutable, '/custom/flutter');
    });

    test('uses Flutter SDK bundled Dart when no Dart SDK is configured', () {
      final environment = CockpitSdkEnvironment.fromEnvironment(
        <String, String>{'FLUTTER_ROOT': p.join('/opt', 'flutter')},
        isWindows: false,
      );

      expect(
        environment.dartExecutable,
        p.join('/opt', 'flutter', 'bin', 'cache', 'dart-sdk', 'bin', 'dart'),
      );
      expect(
        environment.flutterExecutable,
        p.join('/opt', 'flutter', 'bin', 'flutter'),
      );
    });

    test('uses Windows executable names for root variables', () {
      final environment = CockpitSdkEnvironment.fromEnvironment(
        <String, String>{
          'DART_SDK': r'C:\tools\dart-sdk',
          'FLUTTER_SDK': r'C:\tools\flutter',
        },
        isWindows: true,
      );

      expect(environment.dartExecutable, r'C:\tools\dart-sdk\bin\dart.exe');
      expect(
        environment.flutterExecutable,
        r'C:\tools\flutter\bin\flutter.bat',
      );
    });

    test('normalizes Windows Flutter SDK roots with forward slashes', () {
      final environment =
          CockpitSdkEnvironment.fromEnvironment(<String, String>{
            'FLUTTER_ROOT':
                r'C:/hostedtoolcache/windows/flutter/stable-3.32.0-x64/flutter',
          }, isWindows: true);

      expect(
        environment.dartExecutable,
        r'C:\hostedtoolcache\windows\flutter\stable-3.32.0-x64\flutter\bin\cache\dart-sdk\bin\dart.exe',
      );
      expect(
        environment.flutterExecutable,
        r'C:\hostedtoolcache\windows\flutter\stable-3.32.0-x64\flutter\bin\flutter.bat',
      );
      expect(environment.dartExecutable, isNot(contains('/')));
      expect(environment.flutterExecutable, isNot(contains('/')));
    });

    test('current resolves from the supplied process environment', () {
      final environment = CockpitSdkEnvironment.current(
        environment: <String, String>{
          'FLUTTER_ROOT': p.join('/opt', 'flutter'),
        },
        isWindows: false,
      );

      expect(
        environment.flutterExecutable,
        p.join('/opt', 'flutter', 'bin', 'flutter'),
      );
    });

    test('falls back to the current Dart SDK executable before PATH dart', () {
      final environment = CockpitSdkEnvironment.fromEnvironment(
        const <String, String>{},
        currentResolvedExecutable: p.join('/opt', 'dart-sdk', 'bin', 'dart'),
        isWindows: false,
      );

      expect(
        environment.dartExecutable,
        p.join('/opt', 'dart-sdk', 'bin', 'dart'),
      );
    });

    test(
      'falls back to Flutter root around current Dart SDK when available',
      () {
        final environment = CockpitSdkEnvironment.fromEnvironment(
          const <String, String>{},
          currentResolvedExecutable: p.join(
            '/opt',
            'flutter',
            'bin',
            'cache',
            'dart-sdk',
            'bin',
            'dart',
          ),
          isWindows: false,
        );

        expect(
          environment.dartExecutable,
          p.join('/opt', 'flutter', 'bin', 'cache', 'dart-sdk', 'bin', 'dart'),
        );
        expect(
          environment.flutterExecutable,
          p.join('/opt', 'flutter', 'bin', 'flutter'),
        );
      },
    );
  });
}
