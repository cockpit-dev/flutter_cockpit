import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:test/test.dart';

void main() {
  test('web remote session helpers prefer localhost for browser-facing URLs',
      () {
    expect(cockpitRemoteBindHostForPlatform('web'), 'localhost');
    expect(cockpitRemotePublicHostForPlatform('web'), 'localhost');
    expect(cockpitRemoteBindHostForPlatform('ios'), '0.0.0.0');
    expect(cockpitRemotePublicHostForPlatform('ios'), '127.0.0.1');
  });

  test(
    'Android remote session launcher builds, launches, and returns a handle',
    () async {
      final invocations = <String>[];
      final launcher = CockpitAndroidRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner: (executable, arguments,
            {String? workingDirectory}) async {
          invocations.add('$executable ${arguments.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
        portForwarder: _FakeAndroidPortForwarder(forwardedHostPort: 58421),
        applicationIdResolver: ({
          required String projectDir,
          required String buildDirectory,
        }) async =>
            'dev.cockpit.cockpit_demo',
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'android-bootstrap-session',
          platform: 'android',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'android',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: false,
            supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      );

      final handle = await launcher.launch(
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'android',
          deviceId: 'emulator-5554',
          sessionPort: 47331,
        ),
      );

      expect(handle.platform, 'android');
      expect(handle.deviceId, 'emulator-5554');
      expect(handle.appId, 'dev.cockpit.cockpit_demo');
      expect(handle.baseUrl, 'http://127.0.0.1:58421');
      expect(
        invocations,
        contains(
          '${cockpitFlutterExecutable()} build apk --debug --target lib/main.dart --dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true --dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1 --dart-define=FLUTTER_PILOT_REMOTE_PORT=47331 --dart-define=FLUTTER_PILOT_FLUTTER_VERSION=3.38.9',
        ),
      );
      expect(
        invocations,
        contains(
          'adb -s emulator-5554 install -r /workspace/examples/cockpit_demo/build/app/outputs/flutter-apk/app-debug.apk',
        ),
      );
      expect(
        invocations,
        contains(
          'adb -s emulator-5554 shell monkey -p dev.cockpit.cockpit_demo -c android.intent.category.LAUNCHER 1',
        ),
      );
    },
  );

  test(
    'iOS simulator remote session launcher builds, launches, and returns a handle',
    () async {
      final invocations = <String>[];
      final launcher = CockpitIosSimulatorRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner: (executable, arguments,
            {String? workingDirectory}) async {
          invocations.add('$executable ${arguments.join(' ')}');
          return ProcessResult(0, 0, '', '');
        },
        bundleIdResolver: ({required String appBundlePath}) async =>
            'dev.cockpit.cockpitDemo',
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'ios-bootstrap-session',
          platform: 'ios',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'ios',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: false,
            supportedCommands: <CockpitCommandType>[CockpitCommandType.tap],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      );

      final handle = await launcher.launch(
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'ios',
          deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
          sessionPort: 49321,
        ),
      );

      expect(handle.platform, 'ios');
      expect(handle.deviceId, '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC');
      expect(handle.appId, 'dev.cockpit.cockpitDemo');
      expect(handle.baseUrl, 'http://127.0.0.1:49321');
      expect(
        invocations,
        contains(
          '${cockpitFlutterExecutable()} build ios --simulator --debug --no-codesign --target lib/main.dart --dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true --dart-define=FLUTTER_PILOT_REMOTE_HOST=0.0.0.0 --dart-define=FLUTTER_PILOT_REMOTE_PORT=49321 --dart-define=FLUTTER_PILOT_FLUTTER_VERSION=3.38.9',
        ),
      );
      expect(
        invocations,
        contains(
          'xcrun simctl install 6FD25DED-11E9-4AE9-B4B5-EDF4601981DC /workspace/examples/cockpit_demo/build/ios/iphonesimulator/Runner.app',
        ),
      );
      expect(
        invocations,
        contains(
          'xcrun simctl launch 6FD25DED-11E9-4AE9-B4B5-EDF4601981DC dev.cockpit.cockpitDemo',
        ),
      );
    },
  );

  test('platform launcher dispatches macos requests', () async {
    CockpitRemoteSessionLaunchOptions? capturedOptions;
    final launcher = CockpitPlatformRemoteSessionLauncher(
      androidLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected android launch'),
      ),
      iosLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected ios launch'),
      ),
      macosLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (options) => capturedOptions = options,
        handleBuilder: (options) => CockpitRemoteSessionHandle(
          platform: 'macos',
          deviceId: 'macos',
          projectDir: options.projectDir,
          target: options.target,
          appId: 'dev.cockpit.cockpitDemo',
          host: '127.0.0.1',
          hostPort: options.sessionPort,
          devicePort: options.sessionPort,
          baseUrl: 'http://127.0.0.1:${options.sessionPort}',
          launchedAt: DateTime.utc(2026, 3, 24),
        ),
      ),
    );

    final handle = await launcher.launch(
      const CockpitRemoteSessionLaunchOptions(
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        platform: 'macos',
        deviceId: 'macos',
        sessionPort: 47331,
      ),
    );

    expect(capturedOptions?.platform, 'macos');
    expect(handle.platform, 'macos');
    expect(handle.appId, 'dev.cockpit.cockpitDemo');
  });

  test('platform launcher dispatches windows requests', () async {
    CockpitRemoteSessionLaunchOptions? capturedOptions;
    final launcher = CockpitPlatformRemoteSessionLauncher(
      androidLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected android launch'),
      ),
      iosLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected ios launch'),
      ),
      macosLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected macos launch'),
      ),
      windowsLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (options) => capturedOptions = options,
        handleBuilder: (options) => CockpitRemoteSessionHandle(
          platform: 'windows',
          deviceId: 'windows',
          projectDir: options.projectDir,
          target: options.target,
          appId: 'dev.cockpit.cockpit_demo',
          host: '127.0.0.1',
          hostPort: options.sessionPort,
          devicePort: options.sessionPort,
          baseUrl: 'http://127.0.0.1:${options.sessionPort}',
          launchedAt: DateTime.utc(2026, 3, 24),
        ),
      ),
    );

    final handle = await launcher.launch(
      const CockpitRemoteSessionLaunchOptions(
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        platform: 'windows',
        deviceId: 'windows',
        sessionPort: 47331,
      ),
    );

    expect(capturedOptions?.platform, 'windows');
    expect(handle.platform, 'windows');
    expect(handle.appId, 'dev.cockpit.cockpit_demo');
  });

  test('platform launcher dispatches linux requests', () async {
    CockpitRemoteSessionLaunchOptions? capturedOptions;
    final launcher = CockpitPlatformRemoteSessionLauncher(
      androidLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected android launch'),
      ),
      iosLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected ios launch'),
      ),
      macosLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected macos launch'),
      ),
      linuxLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (options) => capturedOptions = options,
        handleBuilder: (options) => CockpitRemoteSessionHandle(
          platform: 'linux',
          deviceId: 'linux',
          projectDir: options.projectDir,
          target: options.target,
          appId: 'dev.cockpit.cockpit_demo',
          host: '127.0.0.1',
          hostPort: options.sessionPort,
          devicePort: options.sessionPort,
          baseUrl: 'http://127.0.0.1:${options.sessionPort}',
          launchedAt: DateTime.utc(2026, 3, 24),
        ),
      ),
    );

    final handle = await launcher.launch(
      const CockpitRemoteSessionLaunchOptions(
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        platform: 'linux',
        deviceId: 'linux',
        sessionPort: 47331,
      ),
    );

    expect(capturedOptions?.platform, 'linux');
    expect(handle.platform, 'linux');
    expect(handle.appId, 'dev.cockpit.cockpit_demo');
  });
}

final class _FakeAndroidPortForwarder extends CockpitAndroidPortForwarder {
  const _FakeAndroidPortForwarder({required this.forwardedHostPort});

  final int forwardedHostPort;

  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) async {
    return forwardedHostPort;
  }
}

final class _CapturingRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  _CapturingRemoteSessionLauncher({
    required this.onLaunch,
    this.handleBuilder,
  });

  final void Function(CockpitRemoteSessionLaunchOptions options) onLaunch;
  final CockpitRemoteSessionHandle Function(
    CockpitRemoteSessionLaunchOptions options,
  )? handleBuilder;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    onLaunch(options);
    return handleBuilder?.call(options) ??
        CockpitRemoteSessionHandle(
          platform: options.platform,
          deviceId: options.deviceId,
          projectDir: options.projectDir,
          target: options.target,
          appId: 'dev.cockpit.capturing',
          host: '127.0.0.1',
          hostPort: options.sessionPort,
          devicePort: options.sessionPort,
          baseUrl: 'http://127.0.0.1:${options.sessionPort}',
          launchedAt: DateTime.utc(2026, 3, 24),
        );
  }
}
