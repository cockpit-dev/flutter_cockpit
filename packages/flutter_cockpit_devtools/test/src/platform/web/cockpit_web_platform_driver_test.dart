import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/platform/web/cockpit_web_platform_driver.dart';
import 'package:test/test.dart';

void main() {
  test(
      'web platform driver reports browser DOM inspection but not device shell',
      () async {
    final driver = CockpitWebPlatformDriver();

    final profile = await driver.describeCapabilities();

    expect(profile.targetKind, CockpitTargetKind.browserPage);
    expect(profile.supportsSurface(CockpitSurfaceKind.browserDom), isTrue);
    expect(
      profile.actionCapabilities,
      contains(CockpitActionCapability.captureScreenshot),
    );
    expect(
      profile.actionCapabilities,
      contains(CockpitActionCapability.startRecording),
    );
    expect(
      profile.actionCapabilities,
      contains(CockpitActionCapability.stopRecording),
    );
    expect(
      profile.evidenceCapabilities,
      contains(CockpitEvidenceCapability.domSnapshot),
    );
    expect(
      profile.evidenceCapabilities,
      contains(CockpitEvidenceCapability.windowCapture),
    );
    expect(
      profile.evidenceCapabilities,
      contains(CockpitEvidenceCapability.screenRecording),
    );
    expect(
      profile.actionCapabilities,
      isNot(contains(CockpitActionCapability.runShell)),
    );
    expect(
      profile.qualityFlags,
      contains(CockpitQualityFlag.requiresBrowserDriver),
    );
  });
}
