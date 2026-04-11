import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/platform/linux/cockpit_linux_platform_driver.dart';
import 'package:test/test.dart';

void main() {
  test('linux platform driver reports desktop automation capabilities',
      () async {
    final driver = CockpitLinuxPlatformDriver();

    final profile = await driver.describeCapabilities();

    expect(profile.targetKind, CockpitTargetKind.desktopApp);
    expect(profile.surfaceKinds, contains(CockpitSurfaceKind.desktopWindow));
    expect(
      profile.actionCapabilities,
      contains(CockpitActionCapability.runShell),
    );
    expect(
      profile.evidenceCapabilities,
      contains(CockpitEvidenceCapability.windowCapture),
    );
    expect(
      profile.evidenceCapabilities,
      contains(CockpitEvidenceCapability.screenRecording),
    );
  });
}
