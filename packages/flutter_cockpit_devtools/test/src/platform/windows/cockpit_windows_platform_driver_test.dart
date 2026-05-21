import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/platform/windows/cockpit_windows_platform_driver.dart';
import 'package:test/test.dart';

void main() {
  test('windows platform driver reports desktop automation capabilities',
      () async {
    final driver = CockpitWindowsPlatformDriver();

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
  });

  test('windows platform driver does not expose evidence adapters by default',
      () {
    final driver = CockpitWindowsPlatformDriver();

    expect(driver.captureAdapter, isNull);
    expect(driver.recordingAdapter, isNull);
  });

  test('windows platform driver exposes evidence adapters when app id is set',
      () {
    final driver = CockpitWindowsPlatformDriver(appId: 'cockpit_demo');

    expect(driver.captureAdapter, isNotNull);
    expect(driver.recordingAdapter, isNotNull);
  });

  test(
    'windows platform driver publishes evidence capabilities when app id is set',
    () async {
      final driver = CockpitWindowsPlatformDriver(appId: 'cockpit_demo');

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
    'windows platform driver can expose screenshots without exposing recording when recording support is disabled',
    () async {
      final driver = CockpitWindowsPlatformDriver(
        appId: 'cockpit_demo',
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
