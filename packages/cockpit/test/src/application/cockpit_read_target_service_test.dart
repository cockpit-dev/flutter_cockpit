import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/application/cockpit_app_handle.dart';
import 'package:cockpit/src/application/cockpit_interactive_result_profile.dart';
import 'package:cockpit/src/application/cockpit_read_app_service.dart';
import 'package:cockpit/src/application/cockpit_read_target_service.dart';
import 'package:cockpit/src/platform/cockpit_platform_driver.dart';
import 'package:cockpit/src/platform/cockpit_platform_driver_registry.dart';
import 'package:cockpit/src/session/cockpit_remote_session_handle.dart';
import 'package:cockpit/src/targets/cockpit_target_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'read target reuses flutter app reads and returns target-first summary',
    () async {
      final target = CockpitTargetHandle.fromAppHandle(
        CockpitAppHandle(
          appId: 'dev.cockpit.demo',
          mode: CockpitAppMode.automation,
          platform: 'android',
          deviceId: 'emulator-5554',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          baseUrl: 'http://127.0.0.1:57331',
          launchedAt: DateTime.utc(2026, 4, 11),
        ),
      );
      final service = CockpitReadTargetService(
        readFlutterTarget: (_) async => CockpitReadAppResult(
          sessionId: 'session-1',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: 'android',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          fallbackTrail: const <CockpitPlaneKind>[
            CockpitPlaneKind.nativeUiPlane,
            CockpitPlaneKind.deviceSystemPlane,
          ],
          recommendedNextStep: 'runNextCommand',
          currentRouteName: '/home',
        ),
      );

      final result = await service.read(
        CockpitReadTargetRequest(
          target: target,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.flutterApp);
      expect(result.foregroundSurface, CockpitSurfaceKind.flutterSemantic);
      expect(result.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
      expect(result.recommendedNextStep, 'runNextCommand');
    },
  );

  test(
    'read target supports desktop remote targets by reusing flutter reads',
    () async {
      final target = CockpitTargetHandle(
        targetId: 'dev.cockpit.desktop.macos',
        targetKind: CockpitTargetKind.desktopApp,
        platform: 'macos',
        deviceId: 'macos',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        connection: const CockpitTargetConnection(
          baseUrl: 'http://127.0.0.1:57331',
        ),
        launchedAt: DateTime.utc(2026, 4, 11),
      );
      final service = CockpitReadTargetService(
        platformDriverRegistry: CockpitPlatformDriverRegistry(
          drivers: <String, CockpitPlatformDriverFactory>{
            'macos': ({required String deviceId}) => _FakePlatformDriver(
              platform: 'macos',
              capabilityProfile: CockpitCapabilityProfile(
                targetKind: CockpitTargetKind.desktopApp,
                surfaceKinds: const <CockpitSurfaceKind>{
                  CockpitSurfaceKind.desktopWindow,
                  CockpitSurfaceKind.hostShell,
                },
                actionCapabilities: const <CockpitActionCapability>{
                  CockpitActionCapability.launchApp,
                },
                evidenceCapabilities: const <CockpitEvidenceCapability>{
                  CockpitEvidenceCapability.windowCapture,
                },
              ),
            ),
          },
        ),
        readFlutterTarget: (_) async => CockpitReadAppResult(
          sessionId: 'desktop-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: 'macos',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          recommendedNextStep: 'runNextCommand',
          currentRouteName: '/desktop-home',
        ),
      );

      final result = await service.read(
        CockpitReadTargetRequest(
          target: target,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.desktopApp);
      expect(
        result.capabilityProfile.surfaceKinds,
        containsAll(<CockpitSurfaceKind>[
          CockpitSurfaceKind.desktopWindow,
          CockpitSurfaceKind.flutterSemantic,
        ]),
      );
      expect(result.foregroundSurface, CockpitSurfaceKind.desktopWindow);
      expect(result.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
    },
  );

  test(
    'read target recovers desktop host capability identity from nested remote session metadata',
    () async {
      final service = CockpitReadTargetService(
        readFlutterTarget: (_) async => CockpitReadAppResult(
          sessionId: 'desktop-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: 'windows',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: true,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
          ),
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          recommendedNextStep: 'runNextCommand',
          currentRouteName: '/desktop-home',
        ),
      );

      final result = await service.read(
        CockpitReadTargetRequest(
          target: CockpitTargetHandle(
            targetId: 'machine-app-1',
            targetKind: CockpitTargetKind.desktopApp,
            platform: 'windows',
            deviceId: 'windows',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            connection: const CockpitTargetConnection(
              baseUrl: 'http://127.0.0.1:57331',
            ),
            launchedAt: DateTime.utc(2026, 5, 10),
            metadata: <String, Object?>{
              'appId': 'machine-app-1',
              'remoteSession': CockpitRemoteSessionHandle(
                platform: 'windows',
                deviceId: 'windows',
                projectDir: '/workspace/examples/cockpit_demo',
                target: 'cockpit/main.dart',
                appId: 'machine-app-1',
                platformAppId: 'cockpit_demo',
                host: '127.0.0.1',
                hostPort: 57331,
                devicePort: 57331,
                baseUrl: 'http://127.0.0.1:57331',
                launchedAt: DateTime.utc(2026, 5, 10),
                processId: 4101,
              ).toJson(),
            },
          ),
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.desktopApp);
      expect(result.foregroundSurface, CockpitSurfaceKind.desktopWindow);
      expect(
        result.capabilityProfile.actionCapabilities,
        contains(CockpitActionCapability.startRecording),
      );
      expect(
        result.capabilityProfile.evidenceCapabilities,
        contains(CockpitEvidenceCapability.screenRecording),
      );
    },
  );

  test(
    'read target returns capability-only summaries for browser targets',
    () async {
      final service = CockpitReadTargetService(
        platformDriverRegistry: CockpitPlatformDriverRegistry(
          drivers: <String, CockpitPlatformDriverFactory>{
            'web': ({required String deviceId}) => _FakePlatformDriver(
              platform: 'web',
              capabilityProfile: CockpitCapabilityProfile(
                targetKind: CockpitTargetKind.browserPage,
                surfaceKinds: const <CockpitSurfaceKind>{
                  CockpitSurfaceKind.browserDom,
                },
                actionCapabilities: const <CockpitActionCapability>{
                  CockpitActionCapability.tap,
                  CockpitActionCapability.captureScreenshot,
                  CockpitActionCapability.startRecording,
                  CockpitActionCapability.stopRecording,
                },
                evidenceCapabilities: const <CockpitEvidenceCapability>{
                  CockpitEvidenceCapability.domSnapshot,
                  CockpitEvidenceCapability.screenRecording,
                },
              ),
            ),
          },
        ),
      );

      final result = await service.read(
        CockpitReadTargetRequest(
          target: CockpitTargetHandle(
            targetId: 'chrome-demo',
            targetKind: CockpitTargetKind.browserPage,
            platform: 'web',
            deviceId: 'chrome',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'web',
            connection: const CockpitTargetConnection(
              baseUrl: 'http://127.0.0.1:57331',
            ),
            launchedAt: DateTime.utc(2026, 4, 11),
          ),
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.browserPage);
      expect(result.foregroundSurface, CockpitSurfaceKind.browserDom);
      expect(result.selectedPlane, CockpitPlaneKind.nativeUiPlane);
      expect(result.recommendedNextStep, 'inspectSurface');
      expect(result.currentRouteName, isNull);
      expect(
        result.capabilityProfile.actionCapabilities,
        contains(CockpitActionCapability.startRecording),
      );
    },
  );

  test(
    'read target reuses flutter app reads for launched browser targets that retain app metadata',
    () async {
      final target = CockpitTargetHandle(
        targetId: 'chrome-demo',
        targetKind: CockpitTargetKind.browserPage,
        platform: 'web',
        deviceId: 'chrome',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'web',
        connection: const CockpitTargetConnection(
          baseUrl: 'http://127.0.0.1:57331',
        ),
        launchedAt: DateTime.utc(2026, 4, 11),
        metadata: const <String, Object?>{
          'appId': 'web-app',
          'appMode': 'development',
          'supportsHotReload': true,
        },
      );
      final service = CockpitReadTargetService(
        platformDriverRegistry: CockpitPlatformDriverRegistry(
          drivers: <String, CockpitPlatformDriverFactory>{
            'web': ({required String deviceId}) => _FakePlatformDriver(
              platform: 'web',
              capabilityProfile: CockpitCapabilityProfile(
                targetKind: CockpitTargetKind.browserPage,
                surfaceKinds: const <CockpitSurfaceKind>{
                  CockpitSurfaceKind.browserDom,
                },
                actionCapabilities: const <CockpitActionCapability>{
                  CockpitActionCapability.tap,
                  CockpitActionCapability.captureScreenshot,
                },
                evidenceCapabilities: const <CockpitEvidenceCapability>{
                  CockpitEvidenceCapability.domSnapshot,
                },
              ),
            ),
          },
        ),
        readFlutterTarget: (_) async => CockpitReadAppResult(
          sessionId: 'web-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: 'web',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: false,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          recommendedNextStep: 'runNextCommand',
          currentRouteName: '/web-home',
        ),
      );

      final result = await service.read(
        CockpitReadTargetRequest(
          target: target,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.browserPage);
      expect(result.foregroundSurface, CockpitSurfaceKind.browserDom);
      expect(result.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
      expect(result.currentRouteName, '/web-home');
      expect(result.recommendedNextStep, 'runNextCommand');
      expect(
        result.capabilityProfile.surfaceKinds,
        containsAll(<CockpitSurfaceKind>[
          CockpitSurfaceKind.browserDom,
          CockpitSurfaceKind.flutterSemantic,
        ]),
      );
    },
  );

  test(
    'read target strips mobile recording capabilities when runtime health reports recording unavailable',
    () async {
      final target =
          CockpitTargetHandle.fromAppHandle(
            CockpitAppHandle(
              appId: 'dev.cockpit.ios.device',
              mode: CockpitAppMode.automation,
              platform: 'ios',
              deviceId: '00008110-0009341C2EF3801E',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              baseUrl: 'http://127.0.0.1:57331',
              launchedAt: DateTime.utc(2026, 4, 17),
            ),
          ).copyWith(
            capabilityProfile: CockpitCapabilityProfile(
              targetKind: CockpitTargetKind.flutterApp,
              surfaceKinds: const <CockpitSurfaceKind>{
                CockpitSurfaceKind.flutterSemantic,
                CockpitSurfaceKind.nativeUi,
              },
              actionCapabilities: const <CockpitActionCapability>{
                CockpitActionCapability.tap,
                CockpitActionCapability.captureScreenshot,
                CockpitActionCapability.startRecording,
                CockpitActionCapability.stopRecording,
              },
              evidenceCapabilities: const <CockpitEvidenceCapability>{
                CockpitEvidenceCapability.flutterScreenshot,
                CockpitEvidenceCapability.nativeScreenshot,
                CockpitEvidenceCapability.screenRecording,
              },
            ),
          );
      final service = CockpitReadTargetService(
        readFlutterTarget: (_) async => CockpitReadAppResult(
          sessionId: 'ios-session',
          transportType: 'remoteHttp',
          capabilities: CockpitCapabilities(
            platform: 'ios',
            transportType: 'remoteHttp',
            supportsInAppControl: true,
            supportsFlutterViewCapture: true,
            supportsNativeScreenCapture: true,
            supportsHostAutomation: false,
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: false,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
            recordingLimitations: const <String>[
              'Native recording requires iOS 14 or newer.',
            ],
          ),
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          recommendedNextStep: 'runNextCommand',
          currentRouteName: '/home',
        ),
      );

      final result = await service.read(
        CockpitReadTargetRequest(
          target: target,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(
        result.capabilityProfile.actionCapabilities,
        isNot(contains(CockpitActionCapability.startRecording)),
      );
      expect(
        result.capabilityProfile.evidenceCapabilities,
        isNot(contains(CockpitEvidenceCapability.screenRecording)),
      );
      expect(
        result.whatMatters,
        contains('Native recording requires iOS 14 or newer.'),
      );
    },
  );
}

final class _FakePlatformDriver implements CockpitPlatformDriver {
  const _FakePlatformDriver({
    required this.platform,
    required this.capabilityProfile,
  });

  @override
  final String platform;
  final CockpitCapabilityProfile capabilityProfile;

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
    return capabilityProfile;
  }
}
