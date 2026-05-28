import 'dart:io';

import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launcher.dart';
import 'package:test/test.dart';

void main() {
  test('flutter executable resolves by host platform', () {
    expect(cockpitFlutterExecutable(isWindows: true), 'flutter.bat');
    expect(cockpitFlutterExecutable(isWindows: false), 'flutter');
    expect(cockpitDartExecutable(isWindows: true), 'dart.bat');
    expect(cockpitDartExecutable(isWindows: false), 'dart');
  });

  test('flutter version reader uses the resolved executable', () async {
    String? capturedExecutable;

    final version = await cockpitReadActiveFlutterVersion(
      isWindows: true,
      processRunner: (executable, arguments) async {
        capturedExecutable = executable;
        return ProcessResult(0, 0, '{"frameworkVersion":"3.32.0"}', '');
      },
    );

    expect(capturedExecutable, 'flutter.bat');
    expect(version, '3.32.0');
  });

  test('launch version resolver prefers explicit version', () async {
    final version = await cockpitResolveFlutterVersionForLaunch(
      flutterExecutable: '/opt/flutter/bin/flutter',
      explicitFlutterVersion: '3.31.0',
      legacyFlutterVersionReader: () async =>
          throw StateError('legacy reader should not be used'),
      flutterVersionForExecutableReader: (_) async =>
          throw StateError('executable reader should not be used'),
    );

    expect(version, '3.31.0');
  });

  test(
    'launch version resolver reads from the configured executable',
    () async {
      String? capturedExecutable;

      final version = await cockpitResolveFlutterVersionForLaunch(
        flutterExecutable: '/opt/flutter/bin/flutter',
        flutterVersionForExecutableReader: (flutterExecutable) async {
          capturedExecutable = flutterExecutable;
          return '3.32.0';
        },
      );

      expect(capturedExecutable, '/opt/flutter/bin/flutter');
      expect(version, '3.32.0');
    },
  );

  test('launch version resolver keeps legacy reader when provided', () async {
    final version = await cockpitResolveFlutterVersionForLaunch(
      flutterExecutable: 'flutter',
      legacyFlutterVersionReader: () async => '3.38.9',
      flutterVersionForExecutableReader: (_) async =>
          throw StateError('executable reader should not be used'),
    );

    expect(version, '3.38.9');
  });

  test('dart executable resolver reuses the current dart process', () async {
    final resolved = await cockpitResolveActiveDartExecutable(
      currentExecutable: Platform.isWindows
          ? r'C:\sdk\bin\dart.bat'
          : '/opt/sdk/bin/dart',
      processRunner: (_, _) async =>
          throw StateError('lookup should not be used when already on dart'),
    );

    expect(
      resolved,
      Platform.isWindows ? r'C:\sdk\bin\dart.bat' : '/opt/sdk/bin/dart',
    );
  });

  test(
    'dart executable resolver falls back to host lookup when needed',
    () async {
      String? capturedExecutable;
      List<String>? capturedArguments;

      final resolved = await cockpitResolveActiveDartExecutable(
        isWindows: false,
        currentExecutable: '/tmp/flutter_tester',
        processRunner: (executable, arguments) async {
          capturedExecutable = executable;
          capturedArguments = arguments;
          return ProcessResult(0, 0, '/opt/homebrew/bin/dart\n', '');
        },
      );

      expect(capturedExecutable, 'which');
      expect(capturedArguments, <String>['dart']);
      expect(resolved, '/opt/homebrew/bin/dart');
    },
  );
}
