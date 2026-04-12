import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_result_profile.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_app_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_remote_status_service.dart';
import 'package:flutter_cockpit_devtools/src/platform/cockpit_platform_driver.dart';
import 'package:flutter_cockpit_devtools/src/platform/cockpit_platform_driver_registry.dart';
import 'package:test/test.dart';

void main() {
  test('read app includes selected plane and recommended next step', () async {
    final app = CockpitAppHandle(
      appId: 'dev.cockpit.demo',
      mode: CockpitAppMode.automation,
      platform: 'android',
      deviceId: 'emulator-5554',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      baseUrl: 'http://127.0.0.1:47331',
      launchedAt: DateTime.utc(2026, 4, 11),
    );
    final service = CockpitReadAppService(
      remoteStatusService: CockpitReadRemoteStatusService(
        readStatus: (_) async => CockpitRemoteSessionStatus(
          sessionId: 'session-1',
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
            supportedCommands: const <CockpitCommandType>[
              CockpitCommandType.tap,
            ],
            supportedLocatorStrategies: CockpitLocatorKind.values,
          ),
          recordingCapabilities: CockpitRecordingCapabilities(
            supportsNativeRecording: true,
            preferredAcceptanceRecordingKind: CockpitRecordingKind.nativeScreen,
          ),
          snapshot: CockpitSnapshot(routeName: '/home'),
        ),
      ),
    );

    final result = await service.read(
      CockpitReadAppRequest(
        app: app,
        resultProfile: const CockpitInteractiveResultProfile.minimal(),
      ),
    );

    expect(result.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
    expect(result.fallbackTrail, <CockpitPlaneKind>[
      CockpitPlaneKind.nativeUiPlane,
      CockpitPlaneKind.deviceSystemPlane,
    ]);
    expect(result.recommendedNextStep, 'runNextCommand');
    expect(result.toJson()['selectedPlane'], 'flutterSemanticPlane');
  });

  test(
    'read app keeps platform-specific capability profile details when the driver exposes extra target abilities',
    () async {
      final app = CockpitAppHandle(
        appId: 'dev.cockpit.web',
        mode: CockpitAppMode.development,
        platform: 'web',
        deviceId: 'chrome',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        baseUrl: 'http://127.0.0.1:48331',
        launchedAt: DateTime.utc(2026, 4, 11),
      );
      final service = CockpitReadAppService(
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
        remoteStatusService: CockpitReadRemoteStatusService(
          readStatus: (_) async => CockpitRemoteSessionStatus(
            sessionId: 'session-web',
            platform: 'web',
            transportType: 'remoteHttp',
            currentRouteName: '/inbox',
            capabilities: CockpitCapabilities(
              platform: 'web',
              transportType: 'remoteHttp',
              supportsInAppControl: true,
              supportsFlutterViewCapture: true,
              supportsNativeScreenCapture: false,
              supportsHostAutomation: false,
              supportedCommands: const <CockpitCommandType>[
                CockpitCommandType.tap,
                CockpitCommandType.captureScreenshot,
              ],
              supportedLocatorStrategies: CockpitLocatorKind.values,
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: false,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            snapshot: CockpitSnapshot(routeName: '/inbox'),
          ),
        ),
      );

      final result = await service.read(
        CockpitReadAppRequest(
          app: app,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(result.capabilities.platform, 'web');
      expect(result.selectedPlane, CockpitPlaneKind.flutterSemanticPlane);
      expect(
        result.capabilities.capabilityProfile?.targetKind,
        CockpitTargetKind.browserPage,
      );
      expect(
        result.capabilities.capabilityProfile?.actionCapabilities,
        contains(CockpitActionCapability.startRecording),
      );
      expect(result.recordingCapabilities.supportsNativeRecording, isTrue);
    },
  );

  test(
    'read app points browser targets at visibility recovery when the route is known but no targets are visible',
    () async {
      final app = CockpitAppHandle(
        appId: 'dev.cockpit.web.zero-targets',
        mode: CockpitAppMode.development,
        platform: 'web',
        deviceId: 'chrome',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        baseUrl: 'http://127.0.0.1:58331',
        launchedAt: DateTime.utc(2026, 4, 12),
      );
      final service = CockpitReadAppService(
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
                      CockpitActionCapability.captureScreenshot,
                    },
                    evidenceCapabilities: const <CockpitEvidenceCapability>{
                      CockpitEvidenceCapability.domSnapshot,
                    },
                    qualityFlags: const <CockpitQualityFlag>{
                      CockpitQualityFlag.requiresBrowserDriver,
                    },
                  ),
                ),
          },
        ),
        remoteStatusService: CockpitReadRemoteStatusService(
          readStatus: (_) async => CockpitRemoteSessionStatus(
            sessionId: 'session-web-zero-targets',
            platform: 'web',
            transportType: 'remoteHttp',
            currentRouteName: '/inbox',
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
              supportsNativeRecording: false,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            snapshot: CockpitSnapshot(
              routeName: '/inbox',
              summary: const CockpitSnapshotSummary(
                visibleTargetCount: 0,
                targetsWithCockpitIdCount: 0,
                targetsWithTextCount: 0,
                styleDetailsIncluded: false,
                diagnosticPropertiesIncluded: false,
                ancestorSummariesIncluded: false,
                rebuildSummaryIncluded: false,
                accessibilitySummaryIncluded: false,
              ),
            ),
          ),
          readSnapshot: (_, __) async => CockpitRemoteSnapshotResponse(
            snapshot: CockpitSnapshot(
              routeName: '/inbox',
              summary: const CockpitSnapshotSummary(
                visibleTargetCount: 0,
                targetsWithCockpitIdCount: 0,
                targetsWithTextCount: 0,
                styleDetailsIncluded: false,
                diagnosticPropertiesIncluded: false,
                ancestorSummariesIncluded: false,
                rebuildSummaryIncluded: false,
                accessibilitySummaryIncluded: false,
              ),
            ),
          ),
        ),
      );

      final result = await service.read(
        CockpitReadAppRequest(
          app: app,
          resultProfile: const CockpitInteractiveResultProfile.standard(),
        ),
      );

      expect(result.uiSummary?.visibleTargetCount, 0);
      expect(result.recommendedNextStep, 'recoverBrowserVisibility');
      expect(result.whatMatters, contains('no visible targets were discovered'));
      expect(result.whatMatters, contains('/inbox'));
    },
  );

  test(
    'read app promotes host automation when the platform driver exposes host shell support',
    () async {
      final app = CockpitAppHandle(
        appId: 'dev.cockpit.macos',
        mode: CockpitAppMode.development,
        platform: 'macos',
        deviceId: 'macos',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'cockpit/main.dart',
        baseUrl: 'http://127.0.0.1:49331',
        launchedAt: DateTime.utc(2026, 4, 11),
      );
      final service = CockpitReadAppService(
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
                      CockpitActionCapability.captureScreenshot,
                      CockpitActionCapability.runShell,
                    },
                    evidenceCapabilities: const <CockpitEvidenceCapability>{
                      CockpitEvidenceCapability.windowCapture,
                    },
                  ),
                ),
          },
        ),
        remoteStatusService: CockpitReadRemoteStatusService(
          readStatus: (_) async => CockpitRemoteSessionStatus(
            sessionId: 'session-macos',
            platform: 'macos',
            transportType: 'remoteHttp',
            currentRouteName: '/inbox',
            capabilities: CockpitCapabilities(
              platform: 'macos',
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
            ),
            recordingCapabilities: CockpitRecordingCapabilities(
              supportsNativeRecording: true,
              preferredAcceptanceRecordingKind:
                  CockpitRecordingKind.nativeScreen,
            ),
            snapshot: CockpitSnapshot(routeName: '/inbox'),
          ),
        ),
      );

      final result = await service.read(
        CockpitReadAppRequest(
          app: app,
          resultProfile: const CockpitInteractiveResultProfile.minimal(),
        ),
      );

      expect(result.capabilities.supportsHostAutomation, isTrue);
      expect(
        result.capabilities.capabilityProfile?.surfaceKinds,
        contains(CockpitSurfaceKind.hostShell),
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
