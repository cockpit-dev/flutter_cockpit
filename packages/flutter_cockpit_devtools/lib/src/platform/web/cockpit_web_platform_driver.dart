import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../cockpit_platform_driver.dart';

final class CockpitWebPlatformDriver implements CockpitPlatformDriver {
  @override
  String get platform => 'web';

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
    return CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.browserPage,
      surfaceKinds: <CockpitSurfaceKind>{
        CockpitSurfaceKind.browserDom,
      },
      actionCapabilities: <CockpitActionCapability>{
        CockpitActionCapability.tap,
        CockpitActionCapability.scroll,
        CockpitActionCapability.typeText,
        CockpitActionCapability.captureScreenshot,
        CockpitActionCapability.readLogs,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        CockpitEvidenceCapability.domSnapshot,
        CockpitEvidenceCapability.windowCapture,
        CockpitEvidenceCapability.runtimeErrors,
        CockpitEvidenceCapability.networkSignals,
      },
      qualityFlags: <CockpitQualityFlag>{
        CockpitQualityFlag.requiresBrowserDriver,
      },
    );
  }
}
