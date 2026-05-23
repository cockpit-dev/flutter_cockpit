import 'package:flutter_cockpit_devtools/src/session/cockpit_session_path.dart';
import 'package:test/test.dart';

void main() {
  test('session path context preserves POSIX separators for POSIX roots', () {
    final context = cockpitSessionPathContext(
      '/workspace/examples/cockpit_demo',
    );

    expect(
      context.join(
        '/workspace/examples/cockpit_demo',
        'build',
        'ios',
        'iphonesimulator',
        'Runner.app',
      ),
      '/workspace/examples/cockpit_demo/build/ios/iphonesimulator/Runner.app',
    );
    expect(
      context.dirname(
        '/workspace/examples/cockpit_demo/build/windows/x64/runner/Debug/cockpit_demo.exe',
      ),
      '/workspace/examples/cockpit_demo/build/windows/x64/runner/Debug',
    );
  });

  test('session path context preserves Windows separators for Windows roots', () {
    final context = cockpitSessionPathContext(r'C:\workspace\cockpit_demo');

    expect(
      context.join(
        r'C:\workspace\cockpit_demo',
        'build',
        'app',
        'outputs',
        'flutter-apk',
        'app-debug.apk',
      ),
      r'C:\workspace\cockpit_demo\build\app\outputs\flutter-apk\app-debug.apk',
    );
    expect(
      context.basenameWithoutExtension(
        r'C:\workspace\cockpit_demo\build\windows\x64\runner\Debug\cockpit_demo.exe',
      ),
      'cockpit_demo',
    );
  });
}
