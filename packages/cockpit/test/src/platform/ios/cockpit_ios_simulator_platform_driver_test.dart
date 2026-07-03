import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';
import 'package:cockpit/src/platform/ios/cockpit_ios_simulator_platform_driver.dart';
import 'package:test/test.dart';

void main() {
  test(
    'ios simulator platform driver reports simulator-only native evidence',
    () async {
      final driver = CockpitIosSimulatorPlatformDriver(
        deviceId: '6FD25DED-11E9-4AE9-B4B5-EDF4601981DC',
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
        contains(CockpitActionCapability.runShell),
      );
      expect(
        profile.evidenceCapabilities,
        contains(CockpitEvidenceCapability.nativeScreenshot),
      );
      expect(
        profile.evidenceCapabilities,
        contains(CockpitEvidenceCapability.screenRecording),
      );
      expect(profile.qualityFlags, contains(CockpitQualityFlag.simulatorOnly));
    },
  );
}
