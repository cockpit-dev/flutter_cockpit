import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_machine_launcher.dart';
import 'package:test/test.dart';

void main() {
  test(
    'launch-app falls back to automation when physical iOS development launch fails',
    () async {
      final remoteHandle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        host: 'fd69:8f18:f0a9::1',
        hostPort: 57331,
        devicePort: 57331,
        baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
        launchedAt: DateTime.utc(2026, 4, 15),
      );

      final service = CockpitLaunchAppService(
        developmentService: CockpitLaunchDevelopmentSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: (_) async {
            throw const CockpitDevelopmentSessionFallbackException(
              code: 'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
              message:
                  'The iOS physical-device remote session became reachable, but flutter run --machine exited before app.start. Automation fallback is safe.',
            );
          },
        ),
        remoteService: CockpitLaunchRemoteSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: _FakeRemoteSessionLauncher(remoteHandle),
          statusReader: (_) async => CockpitRemoteSessionStatus(
            sessionId: 'ios-profile-session',
            platform: 'ios',
            transportType: 'remoteHttp',
            currentRouteName: '/inbox',
            capabilities: CockpitCapabilities(
              platform: 'ios',
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
          ),
        ),
      );

      final result = await service.launch(
        const CockpitLaunchAppRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 57331,
        ),
      );

      expect(result.app.mode, CockpitAppMode.automation);
      expect(result.app.baseUrl, 'http://[fd69:8f18:f0a9::1]:57331');
      expect(result.supervisorLogPath, isNull);
    },
  );

  test(
    'launch-app does not silently downgrade physical iOS to automation for unrelated development failures',
    () async {
      final service = CockpitLaunchAppService(
        developmentService: CockpitLaunchDevelopmentSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: (_) async {
            throw StateError('flutter build failed: missing entitlement.');
          },
        ),
        remoteService: CockpitLaunchRemoteSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: _FakeRemoteSessionLauncher(
            CockpitRemoteSessionHandle(
              platform: 'ios',
              deviceId: '00008110-0009341C2EF3801E',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              appId: 'dev.cockpit.cockpitDemo',
              host: 'fd69:8f18:f0a9::1',
              hostPort: 57331,
              devicePort: 57331,
              baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
              launchedAt: DateTime.utc(2026, 4, 15),
            ),
          ),
        ),
      );

      await expectLater(
        () => service.launch(
          const CockpitLaunchAppRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'ios',
            deviceId: '00008110-0009341C2EF3801E',
            sessionPort: 57331,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('missing entitlement'),
          ),
        ),
      );
    },
  );

  test(
    'launch-app falls back only when physical iOS development reports a safe fallback code',
    () async {
      final remoteHandle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        host: 'fd69:8f18:f0a9::1',
        hostPort: 57331,
        devicePort: 57331,
        baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
        launchedAt: DateTime.utc(2026, 4, 15),
      );

      final service = CockpitLaunchAppService(
        developmentService: CockpitLaunchDevelopmentSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: (_) async {
            throw const CockpitDevelopmentSessionFallbackException(
              code: 'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
              message: 'Automation fallback is safe.',
            );
          },
        ),
        remoteService: CockpitLaunchRemoteSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: _FakeRemoteSessionLauncher(remoteHandle),
          statusReader: (_) async => CockpitRemoteSessionStatus(
            sessionId: 'ios-profile-session',
            platform: 'ios',
            transportType: 'remoteHttp',
            currentRouteName: '/inbox',
            capabilities: CockpitCapabilities(
              platform: 'ios',
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
          ),
        ),
      );

      final result = await service.launch(
        const CockpitLaunchAppRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 57331,
        ),
      );

      expect(result.app.mode, CockpitAppMode.automation);
      expect(result.app.baseUrl, 'http://[fd69:8f18:f0a9::1]:57331');
    },
  );

  test(
    'launch-app reuses the ready physical iOS remote session instead of relaunching automation',
    () async {
      final remoteHandle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        host: 'fd69:8f18:f0a9::1',
        hostPort: 57331,
        devicePort: 57331,
        baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
        launchedAt: DateTime.utc(2026, 4, 15),
      );
      var remoteLaunchCount = 0;
      var remoteStatusReadCount = 0;

      final service = CockpitLaunchAppService(
        developmentService: CockpitLaunchDevelopmentSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: (_) async {
            throw CockpitDevelopmentSessionFallbackException(
              code: 'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
              message: 'Automation fallback is safe.',
              remoteSessionHandle: remoteHandle,
            );
          },
        ),
        remoteService: CockpitLaunchRemoteSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: _CapturingRemoteSessionLauncher(
            onLaunch: (_) => remoteLaunchCount += 1,
          ),
        ),
        remoteStatusReader: (baseUri) async {
          remoteStatusReadCount += 1;
          expect(baseUri, remoteHandle.baseUri);
          return CockpitRemoteSessionStatus(
            sessionId: 'ios-profile-session',
            platform: 'ios',
            transportType: 'remoteHttp',
            currentRouteName: '/inbox',
            capabilities: CockpitCapabilities(
              platform: 'ios',
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
        },
      );

      final result = await service.launch(
        const CockpitLaunchAppRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 57331,
        ),
      );

      expect(remoteLaunchCount, 0);
      expect(remoteStatusReadCount, 1);
      expect(result.app.mode, CockpitAppMode.automation);
      expect(result.app.remoteSession?.baseUrl, remoteHandle.baseUrl);
    },
  );

  test(
    'launch-app still reuses the ready physical iOS remote session when follow-up status probing fails',
    () async {
      final remoteHandle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        host: 'fd69:8f18:f0a9::1',
        hostPort: 57331,
        devicePort: 57331,
        baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
        launchedAt: DateTime.utc(2026, 4, 15),
      );
      var remoteLaunchCount = 0;

      final service = CockpitLaunchAppService(
        developmentService: CockpitLaunchDevelopmentSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: (_) async {
            throw CockpitDevelopmentSessionFallbackException(
              code: 'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
              message: 'Automation fallback is safe.',
              remoteSessionHandle: remoteHandle,
            );
          },
        ),
        remoteService: CockpitLaunchRemoteSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: _CapturingRemoteSessionLauncher(
            onLaunch: (_) => remoteLaunchCount += 1,
          ),
        ),
        remoteStatusReader: (_) async {
          throw StateError('transient health probe failure');
        },
      );

      final result = await service.launch(
        const CockpitLaunchAppRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 57331,
        ),
      );

      expect(remoteLaunchCount, 0);
      expect(result.app.mode, CockpitAppMode.automation);
      expect(result.app.remoteSession?.baseUrl, remoteHandle.baseUrl);
    },
  );

  test(
    'launch-app reuse keeps platform app id absent when physical iOS fallback could not resolve a bundle id',
    () async {
      final remoteHandle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'remote-session-1',
        platformAppIdKnown: false,
        host: 'fd69:8f18:f0a9::1',
        hostPort: 57331,
        devicePort: 57331,
        baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
        launchedAt: DateTime.utc(2026, 4, 15),
      );

      final service = CockpitLaunchAppService(
        developmentService: CockpitLaunchDevelopmentSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: (_) async {
            throw CockpitDevelopmentSessionFallbackException(
              code: 'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
              message: 'Automation fallback is safe.',
              remoteSessionHandle: remoteHandle,
            );
          },
        ),
        remoteService: CockpitLaunchRemoteSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: _CapturingRemoteSessionLauncher(onLaunch: (_) {}),
        ),
        remoteStatusReader: (_) async => CockpitRemoteSessionStatus(
          sessionId: 'ios-profile-session',
          platform: 'ios',
          transportType: 'remoteHttp',
          currentRouteName: '/inbox',
          capabilities: CockpitCapabilities(
            platform: 'ios',
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
        ),
      );

      final result = await service.launch(
        const CockpitLaunchAppRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 57331,
        ),
      );

      expect(result.app.appId, 'remote-session-1');
      expect(result.app.platformAppId, isNull);
    },
  );

  test(
    'launch-app does not silently relaunch automation when fallback session reuse cannot persist the app handle',
    () async {
      final remoteHandle = CockpitRemoteSessionHandle(
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        appId: 'dev.cockpit.cockpitDemo',
        host: 'fd69:8f18:f0a9::1',
        hostPort: 57331,
        devicePort: 57331,
        baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
        launchedAt: DateTime.utc(2026, 4, 15),
      );
      var remoteLaunchCount = 0;
      final tempDirectory = await Directory.systemTemp.createTemp(
        'flutter_cockpit_launch_app_service_test_',
      );
      addTearDown(() async {
        if (await tempDirectory.exists()) {
          await tempDirectory.delete(recursive: true);
        }
      });

      final service = CockpitLaunchAppService(
        developmentService: CockpitLaunchDevelopmentSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: (_) async {
            throw CockpitDevelopmentSessionFallbackException(
              code: 'iosPhysicalRemoteSessionReadyButDevelopmentAttachFailed',
              message: 'Automation fallback is safe.',
              remoteSessionHandle: remoteHandle,
            );
          },
        ),
        remoteService: CockpitLaunchRemoteSessionService(
          entrypointResolver: CockpitEntrypointResolver(exists: (_) => true),
          launcher: _CapturingRemoteSessionLauncher(
            onLaunch: (_) => remoteLaunchCount += 1,
          ),
        ),
        remoteStatusReader: (_) async => CockpitRemoteSessionStatus(
          sessionId: 'ios-profile-session',
          platform: 'ios',
          transportType: 'remoteHttp',
          currentRouteName: '/inbox',
          capabilities: CockpitCapabilities(
            platform: 'ios',
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
        ),
      );

      await expectLater(
        () => service.launch(
          CockpitLaunchAppRequest(
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            platform: 'ios',
            deviceId: '00008110-0009341C2EF3801E',
            sessionPort: 57331,
            appHandlePath: tempDirectory.path,
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(remoteLaunchCount, 0);
    },
  );
}

final class _FakeRemoteSessionLauncher implements CockpitRemoteSessionLauncher {
  const _FakeRemoteSessionLauncher(this.handle);

  final CockpitRemoteSessionHandle handle;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    expect(options.platform, handle.platform);
    expect(options.deviceId, handle.deviceId);
    return handle;
  }
}

final class _CapturingRemoteSessionLauncher
    implements CockpitRemoteSessionLauncher {
  _CapturingRemoteSessionLauncher({
    required this.onLaunch,
  });

  final void Function(CockpitRemoteSessionLaunchOptions options) onLaunch;

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) {
    onLaunch(options);
    throw StateError('remote launch should not have been called');
  }
}
