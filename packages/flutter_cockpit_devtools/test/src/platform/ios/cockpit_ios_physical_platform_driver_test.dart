import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/platform/cockpit_platform_driver_registry.dart';
import 'package:flutter_cockpit_devtools/src/platform/ios/cockpit_ios_physical_platform_driver.dart';
import 'package:flutter_cockpit_devtools/src/platform/ios/cockpit_ios_simulator_platform_driver.dart';
import 'package:test/test.dart';

void main() {
  test('ios physical platform driver reports remote physical-device evidence',
      () async {
    final driver = CockpitIosPhysicalPlatformDriver(
      deviceId: '00008110-0009341C2EF3801E',
    );

    final profile = await driver.describeCapabilities();

    expect(profile.targetKind, CockpitTargetKind.flutterApp);
    expect(profile.surfaceKinds, contains(CockpitSurfaceKind.nativeUi));
    expect(
      profile.actionCapabilities,
      contains(CockpitActionCapability.launchApp),
    );
    expect(
      profile.actionCapabilities,
      isNot(contains(CockpitActionCapability.runShell)),
    );
    expect(
      profile.evidenceCapabilities,
      contains(CockpitEvidenceCapability.flutterScreenshot),
    );
    expect(
      profile.evidenceCapabilities,
      isNot(contains(CockpitEvidenceCapability.nativeScreenshot)),
    );
    expect(
      profile.evidenceCapabilities,
      isNot(contains(CockpitEvidenceCapability.screenRecording)),
    );
    expect(
      profile.qualityFlags,
      isNot(contains(CockpitQualityFlag.simulatorOnly)),
    );
    expect(
      profile.qualityFlags,
      contains(CockpitQualityFlag.requiresForegroundWindow),
    );
  });

  test(
      'platform driver registry dispatches simulator and physical ios separately',
      () {
    final registry = CockpitPlatformDriverRegistry();

    expect(
      registry.resolve(
        platform: 'ios',
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
      ),
      isA<CockpitIosSimulatorPlatformDriver>(),
    );
    expect(
      registry.resolve(
        platform: 'ios',
        deviceId: '00008110-0009341C2EF3801E',
      ),
      isA<CockpitIosPhysicalPlatformDriver>(),
    );
  });
}
