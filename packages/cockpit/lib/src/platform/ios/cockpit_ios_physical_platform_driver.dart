import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../session/cockpit_ios_physical_remote_session_launcher.dart';
import '../../session/cockpit_remote_session_handle.dart';
import '../../session/cockpit_remote_session_launch_options.dart';
import '../cockpit_device_lifecycle_driver.dart';
import '../cockpit_platform_driver.dart';

final class CockpitIosPhysicalPlatformDriver
    implements CockpitPlatformDriver, CockpitDeviceLifecycleDriver {
  CockpitIosPhysicalPlatformDriver({
    required String deviceId,
    CockpitIosPhysicalRemoteSessionLauncher? launcher,
  }) : _deviceId = deviceId,
       _launcher = launcher ?? CockpitIosPhysicalRemoteSessionLauncher();

  final String _deviceId;
  final CockpitIosPhysicalRemoteSessionLauncher _launcher;

  @override
  String get platform => 'ios';

  String get deviceId => _deviceId;

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
    return CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.flutterApp,
      surfaceKinds: <CockpitSurfaceKind>{
        CockpitSurfaceKind.flutterSemantic,
        CockpitSurfaceKind.nativeUi,
      },
      actionCapabilities: <CockpitActionCapability>{
        CockpitActionCapability.launchApp,
        CockpitActionCapability.stopApp,
        CockpitActionCapability.tap,
        CockpitActionCapability.scroll,
        CockpitActionCapability.typeText,
        CockpitActionCapability.captureScreenshot,
        CockpitActionCapability.readLogs,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        CockpitEvidenceCapability.flutterScreenshot,
        CockpitEvidenceCapability.appLogs,
        CockpitEvidenceCapability.runtimeErrors,
        CockpitEvidenceCapability.networkSignals,
      },
      qualityFlags: <CockpitQualityFlag>{
        CockpitQualityFlag.requiresForegroundWindow,
      },
    );
  }

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) {
    return _launcher.launch(options);
  }
}
