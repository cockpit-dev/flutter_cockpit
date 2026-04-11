import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_app_handle.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_app_service.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_launch_target_service.dart';
import 'package:flutter_cockpit_devtools/src/platform/cockpit_platform_driver.dart';
import 'package:flutter_cockpit_devtools/src/platform/cockpit_platform_driver_registry.dart';
import 'package:test/test.dart';

void main() {
  test('launch target wraps flutter app launch results in a target handle',
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
  });

  test('launch target maps desktop platforms to desktop target profiles',
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
  });
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
