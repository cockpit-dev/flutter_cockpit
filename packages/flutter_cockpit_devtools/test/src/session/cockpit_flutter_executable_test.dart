import 'dart:io';

import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launcher.dart';
import 'package:test/test.dart';

void main() {
  test('flutter executable resolves by host platform', () {
    expect(cockpitFlutterExecutable(isWindows: true), 'flutter.bat');
    expect(cockpitFlutterExecutable(isWindows: false), 'flutter');
  });

  test('flutter version reader uses the resolved executable', () async {
    String? capturedExecutable;

    final version = await cockpitReadActiveFlutterVersion(
      isWindows: true,
      processRunner: (executable, arguments) async {
        capturedExecutable = executable;
        return ProcessResult(0, 0, '{"frameworkVersion":"3.24.0"}', '');
      },
    );

    expect(capturedExecutable, 'flutter.bat');
    expect(version, '3.24.0');
  });
}
