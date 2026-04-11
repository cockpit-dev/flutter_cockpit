import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/platform/android/cockpit_android_platform_driver.dart';
import 'package:test/test.dart';

void main() {
  test(
    'android platform driver reports lifecycle, shell, screenshot, and recording support',
    () async {
      final driver = CockpitAndroidPlatformDriver(deviceId: 'emulator-5554');

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
    },
  );
}
