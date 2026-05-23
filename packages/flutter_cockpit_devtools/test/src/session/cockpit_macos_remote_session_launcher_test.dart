import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_macos_remote_session_launcher.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_launch_options.dart';
import 'package:test/test.dart';

void main() {
  test(
    'macos remote session launcher builds, opens, and returns a handle',
    () async {
      final invocations = <String>[];
      final launcher = CockpitMacosRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              invocations.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, '', '');
            },
        appBundlePathResolver:
            ({required String projectDir, String? flavor}) async =>
                '$projectDir/build/macos/Build/Products/Debug/cockpit_demo.app',
        bundleIdResolver: ({required String appBundlePath}) async =>
            'dev.cockpit.cockpitDemo',
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'macos-bootstrap-session',
          platform: 'macos',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'macos',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
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
          target: 'cockpit/main.dart',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
        ),
      );

      expect(handle.platform, 'macos');
      expect(handle.deviceId, 'macos');
      expect(handle.appId, 'dev.cockpit.cockpitDemo');
      expect(handle.baseUrl, 'http://127.0.0.1:47331');
      expect(
        invocations,
        contains(
          'flutter build macos --debug --target cockpit/main.dart --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1 --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331 --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.38.9',
        ),
      );
      expect(
        invocations,
        contains(
          'osascript -e tell application id "dev.cockpit.cockpitDemo" to quit',
        ),
      );
      expect(
        invocations,
        contains(
          'open -n /workspace/examples/cockpit_demo/build/macos/Build/Products/Debug/cockpit_demo.app',
        ),
      );
    },
  );

  test('macos remote session launcher times out slow build stages', () async {
    final launcher = CockpitMacosRemoteSessionLauncher(
      flutterVersionReader: () async => '3.38.9',
      processRunner: (executable, arguments, {String? workingDirectory}) {
        return Future<ProcessResult>.delayed(
          const Duration(milliseconds: 150),
          () => ProcessResult(0, 0, '', ''),
        );
      },
      now: () => DateTime.utc(2026, 3, 24, 12),
    );

    expect(
      () => launcher.launch(
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
          launchTimeout: Duration(milliseconds: 50),
        ),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'macos remote session launcher prefers a flavor-matching app bundle',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_macos_remote_session_launcher_flavor',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final productsDirectory = Directory(
        '${tempDir.path}/build/macos/Build/Products/Debug',
      );
      await productsDirectory.create(recursive: true);
      final defaultBundle = Directory('${productsDirectory.path}/Orbit.app');
      final flavoredBundle = Directory(
        '${productsDirectory.path}/OrbitStaging.app',
      );
      await flavoredBundle.create(recursive: true);
      await Directory(
        '${flavoredBundle.path}/Contents',
      ).create(recursive: true);
      await File(
        '${flavoredBundle.path}/Contents/Info.plist',
      ).writeAsString('');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await defaultBundle.create(recursive: true);
      await Directory('${defaultBundle.path}/Contents').create(recursive: true);
      await File('${defaultBundle.path}/Contents/Info.plist').writeAsString('');

      String? resolvedBundlePath;
      final launcher = CockpitMacosRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              return ProcessResult(0, 0, '', '');
            },
        bundleIdResolver: ({required String appBundlePath}) async {
          resolvedBundlePath = appBundlePath;
          return 'dev.cockpit.orbitStaging';
        },
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'macos-staging-session',
          platform: 'macos',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'macos',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      );

      await launcher.launch(
        CockpitRemoteSessionLaunchOptions(
          projectDir: tempDir.path,
          target: 'cockpit/main.dart',
          flavor: 'staging',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
        ),
      );

      expect(resolvedBundlePath, flavoredBundle.path);
    },
  );

  test(
    'macos remote session launcher falls back to the newest app bundle',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_macos_remote_session_launcher_recency',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final productsDirectory = Directory(
        '${tempDir.path}/build/macos/Build/Products/Debug',
      );
      await productsDirectory.create(recursive: true);
      final staleBundle = Directory('${productsDirectory.path}/Orbit.app');
      final newestBundle = Directory(
        '${productsDirectory.path}/Cockpit Demo.app',
      );
      await staleBundle.create(recursive: true);
      await Directory('${staleBundle.path}/Contents').create(recursive: true);
      await File(
        '${staleBundle.path}/Contents/Info.plist',
      ).create(recursive: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await newestBundle.create(recursive: true);
      await Directory('${newestBundle.path}/Contents').create(recursive: true);
      await File(
        '${newestBundle.path}/Contents/Info.plist',
      ).create(recursive: true);

      String? resolvedBundlePath;
      final launcher = CockpitMacosRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              return ProcessResult(0, 0, '', '');
            },
        bundleIdResolver: ({required String appBundlePath}) async {
          resolvedBundlePath = appBundlePath;
          return 'dev.cockpit.cockpitDemo';
        },
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'macos-latest-session',
          platform: 'macos',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'macos',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      );

      await launcher.launch(
        CockpitRemoteSessionLaunchOptions(
          projectDir: tempDir.path,
          target: 'cockpit/main.dart',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
        ),
      );

      expect(resolvedBundlePath, newestBundle.path);
    },
  );

  test(
    'macos remote session launcher ignores nested helper app bundles',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_macos_remote_session_launcher_nested',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final productsDirectory = Directory(
        '${tempDir.path}/build/macos/Build/Products/Debug',
      );
      await productsDirectory.create(recursive: true);
      final topLevelBundle = Directory('${productsDirectory.path}/Orbit.app');
      await topLevelBundle.create(recursive: true);
      await Directory(
        '${topLevelBundle.path}/Contents',
      ).create(recursive: true);
      await File(
        '${topLevelBundle.path}/Contents/Info.plist',
      ).create(recursive: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final nestedHelperBundle = Directory(
        '${topLevelBundle.path}/Contents/Helpers/Orbit Helper.app',
      );
      await nestedHelperBundle.create(recursive: true);
      await Directory(
        '${nestedHelperBundle.path}/Contents',
      ).create(recursive: true);
      await File(
        '${nestedHelperBundle.path}/Contents/Info.plist',
      ).create(recursive: true);

      String? resolvedBundlePath;
      final launcher = CockpitMacosRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              return ProcessResult(0, 0, '', '');
            },
        bundleIdResolver: ({required String appBundlePath}) async {
          resolvedBundlePath = appBundlePath;
          return 'dev.cockpit.orbit';
        },
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'macos-nested-session',
          platform: 'macos',
          transportType: 'remoteHttp',
          currentRouteName: '/home',
          capabilities: CockpitCapabilities(
            platform: 'macos',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      );

      await launcher.launch(
        CockpitRemoteSessionLaunchOptions(
          projectDir: tempDir.path,
          target: 'cockpit/main.dart',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 47331,
        ),
      );

      expect(resolvedBundlePath, topLevelBundle.path);
    },
  );
}
