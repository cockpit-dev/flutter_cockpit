import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/platform/ios/cockpit_ios_device_connection.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('web remote session helpers use explicit IPv4 loopback endpoints', () {
    expect(cockpitRemoteBindHostForPlatform('web'), '127.0.0.1');
    expect(cockpitRemotePublicHostForPlatform('web'), '127.0.0.1');
    expect(cockpitRemoteBindHostForPlatform('ios'), '0.0.0.0');
    expect(cockpitRemotePublicHostForPlatform('ios'), '127.0.0.1');
  });

  test(
    'Android remote session launcher builds, launches, and returns a handle',
    () async {
      final invocations = <String>[];
      final launcher = CockpitAndroidRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              invocations.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, '', '');
            },
        portForwarder: _FakeAndroidPortForwarder(forwardedHostPort: 58421),
        buildArtifactResolver:
            ({
              required String projectDir,
              required String buildDirectory,
              String? flavor,
            }) async => const CockpitAndroidBuildArtifact(
              applicationId: 'dev.cockpit.cockpit_demo',
              apkPath:
                  '/workspace/examples/cockpit_demo/build/app/outputs/flutter-apk/app-debug.apk',
            ),
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
          '${cockpitFlutterExecutable()} build apk --debug --target lib/main.dart --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1 --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331 --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.38.9',
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
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              invocations.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, '', '');
            },
        appBundlePathResolver: ({required projectDir, String? flavor}) async {
          expect(flavor, isNull);
          return '/workspace/examples/cockpit_demo/build/ios/iphonesimulator/Runner.app';
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
          '${cockpitFlutterExecutable()} build ios --simulator --debug --no-codesign --target lib/main.dart --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=0.0.0.0 --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=49321 --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.38.9',
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

  test(
    'iOS simulator remote session launcher times out slow build stages',
    () async {
      final launcher = CockpitIosSimulatorRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner: (executable, arguments, {String? workingDirectory}) =>
            Completer<ProcessResult>().future,
        appBundlePathResolver: ({required projectDir, String? flavor}) async =>
            '/workspace/examples/cockpit_demo/build/ios/iphonesimulator/Runner.app',
        bundleIdResolver: ({required String appBundlePath}) async =>
            'dev.cockpit.cockpitDemo',
        statusReader: (_) async =>
            throw StateError('status should not be read'),
        now: () => DateTime.utc(2026, 3, 24, 12),
      );

      expect(
        () => launcher
            .launch(
              const CockpitRemoteSessionLaunchOptions(
                projectDir: '/workspace/examples/cockpit_demo',
                target: 'lib/main.dart',
                platform: 'ios',
                deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
                sessionPort: 49321,
                launchTimeout: Duration(milliseconds: 50),
              ),
            )
            .timeout(
              const Duration(milliseconds: 120),
              onTimeout: () =>
                  throw StateError('launcher did not enforce build timeout'),
            ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test(
    'iOS physical-device remote session launcher runs profile no-resident and uses the tunnel address',
    () async {
      final invocations = <String>[];
      final launcher = CockpitIosPhysicalRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              invocations.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, '', '');
            },
        deviceConnectionResolver: (deviceId) async {
          expect(deviceId, '00008110-0009341C2EF3801E');
          return const CockpitIosDeviceConnection(
            isPhysical: true,
            tunnelIpAddress: 'fd69:8f18:f0a9::1',
          );
        },
        appBundlePathResolver: ({required projectDir, String? flavor}) async {
          expect(flavor, isNull);
          return '/workspace/examples/cockpit_demo/build/ios/iphoneos/Runner.app';
        },
        bundleIdResolver: ({required String appBundlePath}) async =>
            'dev.cockpit.cockpitDemo',
        statusReader: (baseUri) async => CockpitRemoteSessionStatus(
          sessionId: 'ios-device-bootstrap-session',
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
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 57331,
        ),
      );

      expect(handle.platform, 'ios');
      expect(handle.deviceId, '00008110-0009341C2EF3801E');
      expect(handle.appId, 'dev.cockpit.cockpitDemo');
      expect(handle.baseUrl, 'http://[fd69:8f18:f0a9::1]:57331');
      expect(
        invocations,
        contains(
          '${cockpitFlutterExecutable()} run -d 00008110-0009341C2EF3801E --profile --no-resident --target cockpit/main.dart --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=:: --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=57331 --dart-define=FLUTTER_COCKPIT_ENABLE_HTTP_NETWORK_OBSERVER=false --dart-define=FLUTTER_COCKPIT_ENABLE_RUNTIME_OBSERVER=false --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.38.9',
        ),
      );
    },
  );

  test(
    'iOS physical-device remote session launcher times out slow run stages',
    () async {
      final launcher = CockpitIosPhysicalRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner: (executable, arguments, {String? workingDirectory}) =>
            Completer<ProcessResult>().future,
        deviceConnectionResolver: (_) async => const CockpitIosDeviceConnection(
          isPhysical: true,
          tunnelIpAddress: 'fd69:8f18:f0a9::1',
        ),
        appBundlePathResolver: ({required projectDir, String? flavor}) async =>
            '/workspace/examples/cockpit_demo/build/ios/iphoneos/Runner.app',
        bundleIdResolver: ({required String appBundlePath}) async =>
            'dev.cockpit.cockpitDemo',
        statusReader: (_) async =>
            throw StateError('status should not be read'),
        now: () => DateTime.utc(2026, 3, 24, 12),
      );

      expect(
        () => launcher
            .launch(
              const CockpitRemoteSessionLaunchOptions(
                projectDir: '/workspace/examples/cockpit_demo',
                target: 'cockpit/main.dart',
                platform: 'ios',
                deviceId: '00008110-0009341C2EF3801E',
                sessionPort: 57331,
                launchTimeout: Duration(milliseconds: 50),
              ),
            )
            .timeout(
              const Duration(milliseconds: 120),
              onTimeout: () =>
                  throw StateError('launcher did not enforce run timeout'),
            ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test(
    'Android remote session launcher forwards flavor and resolves app id plus APK path from build metadata',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_android_remote_session_launcher_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final outputDirectory = Directory(
        p.join(tempDir.path, 'build', 'app', 'outputs', 'flutter-apk'),
      );
      await outputDirectory.create(recursive: true);
      final apkPath = p.join(outputDirectory.path, 'app-staging-debug.apk');
      await File(apkPath).writeAsBytes(const <int>[1, 2, 3]);
      await File(
        p.join(outputDirectory.path, 'output-metadata.json'),
      ).writeAsString('''
{"applicationId":"dev.example.staging","variantName":"stagingDebug","elements":[{"outputFile":"app-staging-debug.apk"}]}
''');

      final invocations = <String>[];
      final launcher = CockpitAndroidRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              invocations.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, '', '');
            },
        portForwarder: _FakeAndroidPortForwarder(forwardedHostPort: 58421),
        statusReader: (baseUri) async => _readyStatus('android'),
      );

      final handle = await launcher.launch(
        CockpitRemoteSessionLaunchOptions(
          projectDir: tempDir.path,
          target: 'lib/main.dart',
          flavor: 'staging',
          platform: 'android',
          deviceId: 'emulator-5554',
          sessionPort: 47331,
        ),
      );

      expect(handle.appId, 'dev.example.staging');
      expect(
        invocations,
        contains(
          '${cockpitFlutterExecutable()} build apk --debug --target lib/main.dart --flavor staging --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=127.0.0.1 --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=47331 --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.38.9',
        ),
      );
      expect(invocations, contains('adb -s emulator-5554 install -r $apkPath'));
      expect(
        invocations,
        contains(
          'adb -s emulator-5554 shell monkey -p dev.example.staging -c android.intent.category.LAUNCHER 1',
        ),
      );
    },
  );

  test('Android remote session launcher times out slow build stages', () async {
    final launcher = CockpitAndroidRemoteSessionLauncher(
      flutterVersionReader: () async => '3.38.9',
      processRunner: (executable, arguments, {String? workingDirectory}) =>
          Completer<ProcessResult>().future,
      buildArtifactResolver:
          ({
            required String projectDir,
            required String buildDirectory,
            String? flavor,
          }) async => const CockpitAndroidBuildArtifact(
            applicationId: 'dev.cockpit.cockpit_demo',
            apkPath:
                '/workspace/examples/cockpit_demo/build/app/outputs/flutter-apk/app-debug.apk',
          ),
      statusReader: (_) async => throw StateError('status should not be read'),
      now: () => DateTime.utc(2026, 3, 24, 12),
    );

    expect(
      () => launcher
          .launch(
            const CockpitRemoteSessionLaunchOptions(
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'lib/main.dart',
              platform: 'android',
              deviceId: 'emulator-5554',
              sessionPort: 47331,
              launchTimeout: Duration(milliseconds: 50),
            ),
          )
          .timeout(
            const Duration(milliseconds: 120),
            onTimeout: () =>
                throw StateError('launcher did not enforce build timeout'),
          ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test(
    'iOS simulator launcher forwards flavor and resolves the built app bundle path dynamically',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_ios_simulator_remote_session_launcher_test',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final appBundleDirectory = Directory(
        p.join(
          tempDir.path,
          'build',
          'ios',
          'iphonesimulator',
          'OrbitStaging.app',
        ),
      );
      await appBundleDirectory.create(recursive: true);

      final invocations = <String>[];
      String? resolvedAppBundlePath;
      final launcher = CockpitIosSimulatorRemoteSessionLauncher(
        flutterVersionReader: () async => '3.38.9',
        processRunner:
            (executable, arguments, {String? workingDirectory}) async {
              invocations.add('$executable ${arguments.join(' ')}');
              return ProcessResult(0, 0, '', '');
            },
        bundleIdResolver: ({required String appBundlePath}) async {
          resolvedAppBundlePath = appBundlePath;
          return 'dev.cockpit.orbitStaging';
        },
        statusReader: (baseUri) async => _readyStatus('ios'),
      );

      final handle = await launcher.launch(
        CockpitRemoteSessionLaunchOptions(
          projectDir: tempDir.path,
          target: 'lib/main.dart',
          flavor: 'staging',
          platform: 'ios',
          deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
          sessionPort: 49321,
        ),
      );

      expect(handle.appId, 'dev.cockpit.orbitStaging');
      expect(resolvedAppBundlePath, appBundleDirectory.path);
      expect(
        invocations,
        contains(
          '${cockpitFlutterExecutable()} build ios --simulator --debug --no-codesign --target lib/main.dart --flavor staging --dart-define=FLUTTER_COCKPIT_REMOTE_ENABLED=true --dart-define=FLUTTER_COCKPIT_REMOTE_HOST=0.0.0.0 --dart-define=FLUTTER_COCKPIT_REMOTE_PORT=49321 --dart-define=FLUTTER_COCKPIT_FLUTTER_VERSION=3.38.9',
        ),
      );
      expect(
        invocations,
        contains(
          'xcrun simctl install 6FD25DED-11E9-4AE9-B4B5-EDF4601981DC ${appBundleDirectory.path}',
        ),
      );
    },
  );

  test('iOS simulator launcher ignores nested helper app bundles', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_ios_simulator_remote_session_launcher_nested',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final topLevelBundle = Directory(
      p.join(tempDir.path, 'build', 'ios', 'iphonesimulator', 'Runner.app'),
    );
    await topLevelBundle.create(recursive: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final nestedBundle = Directory(
      p.join(topLevelBundle.path, 'Frameworks', 'Runner Helper.app'),
    );
    await nestedBundle.create(recursive: true);

    String? resolvedAppBundlePath;
    final launcher = CockpitIosSimulatorRemoteSessionLauncher(
      flutterVersionReader: () async => '3.38.9',
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        return ProcessResult(0, 0, '', '');
      },
      bundleIdResolver: ({required String appBundlePath}) async {
        resolvedAppBundlePath = appBundlePath;
        return 'dev.cockpit.cockpitDemo';
      },
      statusReader: (baseUri) async => _readyStatus('ios'),
    );

    await launcher.launch(
      CockpitRemoteSessionLaunchOptions(
        projectDir: tempDir.path,
        target: 'lib/main.dart',
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
        sessionPort: 49321,
      ),
    );

    expect(resolvedAppBundlePath, topLevelBundle.path);
  });

  test('iOS physical launcher ignores nested helper app bundles', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_ios_physical_remote_session_launcher_nested',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final topLevelBundle = Directory(
      p.join(tempDir.path, 'build', 'ios', 'iphoneos', 'Runner.app'),
    );
    await topLevelBundle.create(recursive: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final nestedBundle = Directory(
      p.join(topLevelBundle.path, 'Watch', 'Runner Watch.app'),
    );
    await nestedBundle.create(recursive: true);

    String? resolvedAppBundlePath;
    final launcher = CockpitIosPhysicalRemoteSessionLauncher(
      flutterVersionReader: () async => '3.38.9',
      processRunner: (executable, arguments, {String? workingDirectory}) async {
        return ProcessResult(0, 0, '', '');
      },
      deviceConnectionResolver: (_) async => const CockpitIosDeviceConnection(
        isPhysical: true,
        tunnelIpAddress: 'fd69:8f18:f0a9::1',
      ),
      bundleIdResolver: ({required String appBundlePath}) async {
        resolvedAppBundlePath = appBundlePath;
        return 'dev.cockpit.cockpitDemo';
      },
      statusReader: (baseUri) async => _readyStatus('ios'),
    );

    await launcher.launch(
      CockpitRemoteSessionLaunchOptions(
        projectDir: tempDir.path,
        target: 'cockpit/main.dart',
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
        sessionPort: 57331,
      ),
    );

    expect(resolvedAppBundlePath, topLevelBundle.path);
  });

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

  test(
    'platform launcher dispatches simulator and physical iOS separately',
    () async {
      var simulatorLaunchCount = 0;
      var physicalLaunchCount = 0;
      final launcher = CockpitPlatformRemoteSessionLauncher(
        iosLauncher: _CapturingRemoteSessionLauncher(
          onLaunch: (options) {
            simulatorLaunchCount += 1;
            expect(options.deviceId, '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC');
          },
        ),
        iosPhysicalLauncher: _CapturingRemoteSessionLauncher(
          onLaunch: (options) {
            physicalLaunchCount += 1;
            expect(options.deviceId, '00008110-0009341C2EF3801E');
          },
        ),
      );

      await launcher.launch(
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          platform: 'ios',
          deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
          sessionPort: 49321,
        ),
      );
      await launcher.launch(
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 57331,
        ),
      );

      expect(simulatorLaunchCount, 1);
      expect(physicalLaunchCount, 1);
    },
  );

  test('platform launcher rejects unsupported web automation launches', () {
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
        onLaunch: (_) => fail('unexpected windows launch'),
      ),
      linuxLauncher: _CapturingRemoteSessionLauncher(
        onLaunch: (_) => fail('unexpected linux launch'),
      ),
    );

    expect(
      () => launcher.launch(
        const CockpitRemoteSessionLaunchOptions(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'web/main.dart',
          platform: 'web',
          deviceId: 'chrome',
          sessionPort: 57331,
        ),
      ),
      throwsA(
        isA<CockpitApplicationServiceException>()
            .having(
              (error) => error.code,
              'code',
              'unsupportedAutomationPlatform',
            )
            .having((error) => error.details['platform'], 'platform', 'web'),
      ),
    );
  });

  test(
    'wait for remote session readiness enforces the overall timeout on a hanging probe',
    () async {
      expect(
        () =>
            cockpitWaitForRemoteSessionReady(
              baseUri: Uri.parse('http://127.0.0.1:47331'),
              timeout: const Duration(milliseconds: 50),
              statusReader: (_) =>
                  Completer<CockpitRemoteSessionStatus>().future,
            ).timeout(
              const Duration(milliseconds: 120),
              onTimeout: () =>
                  throw StateError('wait helper did not enforce probe timeout'),
            ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test(
    'wait for remote session readiness caps retry delays to the remaining deadline',
    () async {
      expect(
        () =>
            cockpitWaitForRemoteSessionReady(
              baseUri: Uri.parse('http://127.0.0.1:47331'),
              timeout: const Duration(milliseconds: 50),
              statusReader: (_) async => throw StateError('still booting'),
            ).timeout(
              const Duration(milliseconds: 120),
              onTimeout: () => throw StateError(
                'wait helper slept past the remaining deadline',
              ),
            ),
        throwsA(isA<TimeoutException>()),
      );
    },
  );
}

CockpitRemoteSessionStatus _readyStatus(String platform) {
  return CockpitRemoteSessionStatus(
    sessionId: 'remote-session-1',
    platform: platform,
    transportType: 'remoteHttp',
    currentRouteName: '/inbox',
    capabilities: CockpitCapabilities(
      platform: platform,
      transportType: 'remoteHttp',
      supportsInAppControl: true,
      supportsFlutterViewCapture: true,
      supportsNativeScreenCapture: true,
      supportsHostAutomation: false,
    ),
    recordingCapabilities: CockpitRecordingCapabilities(
      supportsNativeRecording: true,
    ),
    snapshot: CockpitSnapshot(routeName: '/inbox'),
  );
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
  _CapturingRemoteSessionLauncher({required this.onLaunch, this.handleBuilder});

  final void Function(CockpitRemoteSessionLaunchOptions options) onLaunch;
  final CockpitRemoteSessionHandle Function(
    CockpitRemoteSessionLaunchOptions options,
  )?
  handleBuilder;

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
