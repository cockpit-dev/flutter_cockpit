import 'package:flutter/foundation.dart';
import 'package:flutter_cockpit/src/runtime/cockpit_remote_session_platform.dart';
import 'package:test/test.dart';

void main() {
  test('resolveCockpitRemoteSessionPlatform returns web for browser sessions',
      () {
    final platform = resolveCockpitRemoteSessionPlatform(
      isWeb: true,
      targetPlatform: TargetPlatform.macOS,
    );

    expect(platform, 'web');
  });

  test(
      'resolveCockpitRemoteSessionPlatform keeps the host target platform for non-web sessions',
      () {
    final platform = resolveCockpitRemoteSessionPlatform(
      isWeb: false,
      targetPlatform: TargetPlatform.android,
    );

    expect(platform, 'android');
  });

  test(
      'resolveCockpitRemoteSessionPlatform normalizes Apple target platform names to repository canonical values',
      () {
    expect(
      resolveCockpitRemoteSessionPlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      ),
      'ios',
    );
    expect(
      resolveCockpitRemoteSessionPlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.macOS,
      ),
      'macos',
    );
  });
}
