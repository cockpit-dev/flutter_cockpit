import 'package:flutter_cockpit/src/runtime/cockpit_runtime_environment.dart';
import 'package:test/test.dart';

void main() {
  test(
    'resolveCockpitRuntimeEnvironment omits environment when runtime version is unsupported',
    () {
      final environment = resolveCockpitRuntimeEnvironment(
        platform: 'web',
        configuredFlutterVersion: '3.38.9',
        runtimeVersionReader: () {
          throw UnsupportedError('Platform._version');
        },
      );

      expect(environment, isNull);
    },
  );

  test('resolveCockpitRuntimeEnvironment parses provided runtime versions', () {
    final environment = resolveCockpitRuntimeEnvironment(
      platform: 'android',
      configuredFlutterVersion: '3.38.9',
      runtimeVersion: '3.6.0 (stable) (Tue Jan 1 00:00:00 2026 +0000)',
    );

    expect(environment?.platform, 'android');
    expect(environment?.flutterVersion, '3.38.9');
    expect(environment?.dartVersion, '3.6.0');
  });
}
