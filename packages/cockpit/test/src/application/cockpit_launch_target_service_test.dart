import 'package:cockpit_protocol/cockpit_protocol.dart';
import 'package:cockpit/src/application/cockpit_app_handle.dart';
import 'package:cockpit/src/application/cockpit_launch_app_service.dart';
import 'package:cockpit/src/application/cockpit_launch_target_service.dart';
import 'package:cockpit/src/application/cockpit_read_app_service.dart';
import 'package:cockpit/src/development/cockpit_development_session_handle.dart';
import 'package:cockpit/src/platform/cockpit_platform_driver.dart';
import 'package:cockpit/src/platform/cockpit_platform_driver_registry.dart';
import 'package:test/test.dart';

void main() {
  test(
    'launch target wraps flutter app launch results in a target handle',
    () async {
      final service = CockpitLaunchTargetService(
        launchFlutterApp: (_) async => CockpitLaunchAppResult(
          app: CockpitAppHandle(
            appId: 'dev.cockpit.demo',
            mode: CockpitAppMode.development,
            platform: 'android',
            deviceId: 'emulator-5554',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 4, 11),
          ),
        ),
      );

      final result = await service.launch(
        const CockpitLaunchTargetRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platform: 'android',
          deviceId: 'emulator-5554',
          sessionPort: 57331,
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.flutterApp);
      expect(result.target.baseUri.toString(), 'http://127.0.0.1:57331');
      expect(result.app?.appId, 'dev.cockpit.demo');
    },
  );

  test(
    'launch target maps desktop platforms to desktop target profiles',
    () async {
      final service = CockpitLaunchTargetService(
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
                  CockpitActionCapability.runShell,
                },
                evidenceCapabilities: const <CockpitEvidenceCapability>{
                  CockpitEvidenceCapability.windowCapture,
                },
              ),
            ),
          },
        ),
        launchFlutterApp: (_) async => CockpitLaunchAppResult(
          app: CockpitAppHandle(
            appId: 'dev.cockpit.desktop.macos',
            mode: CockpitAppMode.development,
            platform: 'macos',
            deviceId: 'macos',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 4, 11),
          ),
        ),
      );

      final result = await service.launch(
        const CockpitLaunchTargetRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platform: 'macos',
          deviceId: 'macos',
          sessionPort: 57331,
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.desktopApp);
      expect(
        result.target.capabilityProfile?.surfaceKinds,
        contains(CockpitSurfaceKind.desktopWindow),
      );
    },
  );

  test(
    'launch target normalizes web targets to browser-page profiles',
    () async {
      final service = CockpitLaunchTargetService(
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
                  CockpitActionCapability.launchApp,
                },
                evidenceCapabilities: const <CockpitEvidenceCapability>{
                  CockpitEvidenceCapability.domSnapshot,
                },
              ),
            ),
          },
        ),
        launchFlutterApp: (_) async => CockpitLaunchAppResult(
          app: CockpitAppHandle(
            appId: 'web-app',
            mode: CockpitAppMode.development,
            platform: 'web',
            deviceId: 'chrome',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'web/main.dart',
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 4, 11),
          ),
        ),
      );

      final result = await service.launch(
        const CockpitLaunchTargetRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platform: 'web',
          deviceId: 'chrome',
          sessionPort: 57331,
          mode: CockpitAppMode.development,
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.browserPage);
      expect(
        result.target.capabilityProfile?.surfaceKinds,
        contains(CockpitSurfaceKind.browserDom),
      );
      expect(result.app?.platform, 'web');
    },
  );

  test(
    'launch target recomputes desktop host evidence from the launched app metadata',
    () async {
      final service = CockpitLaunchTargetService(
        launchFlutterApp: (_) async => CockpitLaunchAppResult(
          app: CockpitAppHandle(
            appId: 'dev.cockpit.desktop.windows',
            mode: CockpitAppMode.automation,
            platform: 'windows',
            deviceId: 'windows',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            baseUrl: 'http://127.0.0.1:57331',
            launchedAt: DateTime.utc(2026, 4, 17),
            platformAppId: 'cockpit_demo',
            processId: 4101,
          ),
        ),
      );

      final result = await service.launch(
        const CockpitLaunchTargetRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platform: 'windows',
          deviceId: 'windows',
          sessionPort: 57331,
          mode: CockpitAppMode.automation,
        ),
      );

      expect(result.target.targetKind, CockpitTargetKind.desktopApp);
      expect(
        result.target.capabilityProfile?.actionCapabilities,
        contains(CockpitActionCapability.captureScreenshot),
      );
      expect(
        result.target.capabilityProfile?.actionCapabilities,
        contains(CockpitActionCapability.startRecording),
      );
      expect(
        result.target.capabilityProfile?.evidenceCapabilities,
        contains(CockpitEvidenceCapability.windowCapture),
      );
      expect(
        result.target.capabilityProfile?.evidenceCapabilities,
        contains(CockpitEvidenceCapability.screenRecording),
      );
      expect(result.target.metadata['processId'], 4101);
    },
  );

  test(
    'launch target uses the launched app status to keep the capability surface truthful',
    () async {
      final service = CockpitLaunchTargetService(
        platformDriverRegistry: CockpitPlatformDriverRegistry(
          drivers: <String, CockpitPlatformDriverFactory>{
            'ios': ({required String deviceId}) => _FakePlatformDriver(
              platform: 'ios',
              capabilityProfile: CockpitCapabilityProfile(
                targetKind: CockpitTargetKind.flutterApp,
                surfaceKinds: const <CockpitSurfaceKind>{
                  CockpitSurfaceKind.flutterSemantic,
                  CockpitSurfaceKind.nativeUi,
                },
                actionCapabilities: const <CockpitActionCapability>{
                  CockpitActionCapability.launchApp,
                  CockpitActionCapability.stopApp,
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
            ),
          },
        ),
        readApp: (_) async => CockpitReadAppResult(
          sessionId: 'session-ios-device',
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
              CockpitCommandType.captureScreenshot,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
            capabilityProfile: CockpitCapabilityProfile(
              targetKind: CockpitTargetKind.flutterApp,
              surfaceKinds: const <CockpitSurfaceKind>{
                CockpitSurfaceKind.flutterSemantic,
                CockpitSurfaceKind.nativeUi,
              },
              actionCapabilities: const <CockpitActionCapability>{
                CockpitActionCapability.tap,
                CockpitActionCapability.captureScreenshot,
              },
              evidenceCapabilities: const <CockpitEvidenceCapability>{
                CockpitEvidenceCapability.flutterScreenshot,
                CockpitEvidenceCapability.nativeScreenshot,
              },
            ),
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: false,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
            recordingLimitations: const <String>[
              'Native recording requires iOS 14 or newer.',
            ],
          ),
          selectedPlane: CockpitPlaneKind.flutterSemanticPlane,
          fallbackTrail: const <CockpitPlaneKind>[
            CockpitPlaneKind.nativeUiPlane,
            CockpitPlaneKind.deviceSystemPlane,
          ],
          recommendedNextStep: 'runNextCommand',
          whatMatters: 'Native recording requires iOS 14 or newer.',
          app: null,
          currentRouteName: '/home',
        ),
        launchFlutterApp: (_) async => CockpitLaunchAppResult(
          app: CockpitAppHandle(
            appId: 'dev.cockpit.ios.device',
            mode: CockpitAppMode.development,
            platform: 'ios',
            deviceId: '00008110-0009341C2EF3801E',
            projectDir: '/workspace/examples/cockpit_demo',
            target: 'cockpit/main.dart',
            baseUrl: 'http://127.0.0.1:50331',
            launchedAt: DateTime.utc(2026, 5, 10),
            developmentSession: CockpitDevelopmentSessionHandle(
              developmentSessionId: 'dev-session-ios-device',
              platform: 'ios',
              deviceId: '00008110-0009341C2EF3801E',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'cockpit/main.dart',
              appId: 'dev.cockpit.ios.device',
              appBaseUrl: 'http://127.0.0.1:50331',
              supervisorBaseUrl: 'http://127.0.0.1:51331',
              launchedAt: DateTime.utc(2026, 5, 10),
              reloadGeneration: 1,
            ),
          ),
        ),
      );

      final result = await service.launch(
        const CockpitLaunchTargetRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          sessionPort: 50331,
          mode: CockpitAppMode.development,
        ),
      );

      expect(
        result.target.capabilityProfile?.actionCapabilities,
        isNot(contains(CockpitActionCapability.startRecording)),
      );
      expect(
        result.target.capabilityProfile?.evidenceCapabilities,
        isNot(contains(CockpitEvidenceCapability.screenRecording)),
      );
      expect(
        result.target.capabilityProfile?.surfaceKinds,
        contains(CockpitSurfaceKind.flutterSemantic),
      );
      expect(result.recommendedNextStep, 'runNextCommand');
      expect(
        result.whatMatters,
        contains('Native recording requires iOS 14 or newer.'),
      );
      expect(result.toJson()['recommendedNextStep'], 'runNextCommand');
      expect(
        result.toJson()['whatMatters'],
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
