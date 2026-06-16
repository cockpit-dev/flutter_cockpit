import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/platform/macos/cockpit_macos_platform_driver.dart';
import 'package:test/test.dart';

void main() {
  test(
    'macos platform driver reports desktop automation capabilities',
    () async {
      final driver = CockpitMacosPlatformDriver();

      final profile = await driver.describeCapabilities();

      expect(profile.targetKind, CockpitTargetKind.desktopApp);
      expect(profile.surfaceKinds, contains(CockpitSurfaceKind.desktopWindow));
      expect(
        profile.actionCapabilities,
        contains(CockpitActionCapability.runShell),
      );
      expect(
        profile.actionCapabilities,
        isNot(contains(CockpitActionCapability.captureScreenshot)),
      );
      expect(
        profile.actionCapabilities,
        isNot(contains(CockpitActionCapability.startRecording)),
      );
      expect(
        profile.evidenceCapabilities,
        isNot(contains(CockpitEvidenceCapability.windowCapture)),
      );
      expect(
        profile.evidenceCapabilities,
        isNot(contains(CockpitEvidenceCapability.screenRecording)),
      );
    },
  );

  test(
    'macos platform driver does not expose evidence adapters by default',
    () {
      final driver = CockpitMacosPlatformDriver();

      expect(driver.captureAdapter, isNull);
      expect(driver.recordingAdapter, isNull);
    },
  );

  test(
    'macos platform driver exposes evidence adapters when app id is set',
    () {
      final driver = CockpitMacosPlatformDriver(appId: 'dev.cockpit.demo');

      expect(driver.captureAdapter, isNotNull);
      expect(driver.recordingAdapter, isNotNull);
    },
  );

  test(
    'macos platform driver publishes evidence capabilities when app id is set',
    () async {
      final driver = CockpitMacosPlatformDriver(appId: 'dev.cockpit.demo');

      final profile = await driver.describeCapabilities();

      expect(
        profile.actionCapabilities,
        contains(CockpitActionCapability.captureScreenshot),
      );
      expect(
        profile.actionCapabilities,
        contains(CockpitActionCapability.startRecording),
      );
      expect(
        profile.evidenceCapabilities,
        contains(CockpitEvidenceCapability.windowCapture),
      );
      expect(
        profile.evidenceCapabilities,
        contains(CockpitEvidenceCapability.screenRecording),
      );
    },
  );

  test(
    'macos platform driver can expose screenshots without exposing recording when recording support is disabled',
    () async {
      final driver = CockpitMacosPlatformDriver(
        appId: 'dev.cockpit.demo',
        enableDefaultRecordingAdapter: false,
      );

      final profile = await driver.describeCapabilities();

      expect(
        profile.actionCapabilities,
        contains(CockpitActionCapability.captureScreenshot),
      );
      expect(
        profile.actionCapabilities,
        isNot(contains(CockpitActionCapability.startRecording)),
      );
      expect(
        profile.evidenceCapabilities,
        contains(CockpitEvidenceCapability.windowCapture),
      );
      expect(
        profile.evidenceCapabilities,
        isNot(contains(CockpitEvidenceCapability.screenRecording)),
      );
    },
  );
}
