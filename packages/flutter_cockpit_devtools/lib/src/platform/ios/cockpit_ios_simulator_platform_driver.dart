import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../capture/cockpit_simctl_capture_adapter.dart';
import '../../recording/cockpit_simctl_recording_adapter.dart';
import '../../session/cockpit_ios_simulator_remote_session_launcher.dart';
import '../../session/cockpit_remote_session_handle.dart';
import '../../session/cockpit_remote_session_launch_options.dart';
import '../cockpit_device_lifecycle_driver.dart';
import '../cockpit_evidence_driver.dart';
import '../cockpit_platform_driver.dart';

final class CockpitIosSimulatorPlatformDriver
    implements
        CockpitPlatformDriver,
        CockpitDeviceLifecycleDriver,
        CockpitEvidenceDriver {
  CockpitIosSimulatorPlatformDriver({
    required String deviceId,
    CockpitIosSimulatorRemoteSessionLauncher? launcher,
    CockpitSimctlCaptureAdapter? captureAdapter,
    CockpitSimctlRecordingAdapter? recordingAdapter,
  }) : _deviceId = deviceId,
       _launcher = launcher ?? CockpitIosSimulatorRemoteSessionLauncher(),
       _captureAdapter =
           captureAdapter ?? CockpitSimctlCaptureAdapter(deviceId: deviceId),
       _recordingAdapter =
           recordingAdapter ??
           CockpitSimctlRecordingAdapter(deviceId: deviceId);

  final String _deviceId;
  final CockpitIosSimulatorRemoteSessionLauncher _launcher;
  final CockpitSimctlCaptureAdapter _captureAdapter;
  final CockpitSimctlRecordingAdapter _recordingAdapter;

  @override
  String get platform => 'ios';

  String get deviceId => _deviceId;

  @override
  CockpitSimctlCaptureAdapter get captureAdapter => _captureAdapter;

  @override
  CockpitSimctlRecordingAdapter get recordingAdapter => _recordingAdapter;

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
    return CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.flutterApp,
      surfaceKinds: <CockpitSurfaceKind>{
        CockpitSurfaceKind.flutterSemantic,
        CockpitSurfaceKind.nativeUi,
        CockpitSurfaceKind.systemUi,
      },
      actionCapabilities: <CockpitActionCapability>{
        CockpitActionCapability.launchApp,
        CockpitActionCapability.stopApp,
        CockpitActionCapability.openDeepLink,
        CockpitActionCapability.grantPermission,
        CockpitActionCapability.dismissPermissionDialog,
        CockpitActionCapability.tap,
        CockpitActionCapability.scroll,
        CockpitActionCapability.typeText,
        CockpitActionCapability.captureScreenshot,
        CockpitActionCapability.startRecording,
        CockpitActionCapability.stopRecording,
        CockpitActionCapability.readLogs,
        CockpitActionCapability.runShell,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        CockpitEvidenceCapability.flutterScreenshot,
        CockpitEvidenceCapability.nativeScreenshot,
        CockpitEvidenceCapability.screenRecording,
        CockpitEvidenceCapability.appLogs,
        CockpitEvidenceCapability.runtimeErrors,
        CockpitEvidenceCapability.networkSignals,
      },
      qualityFlags: <CockpitQualityFlag>{CockpitQualityFlag.simulatorOnly},
    );
  }

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) {
    return _launcher.launch(options);
  }
}
