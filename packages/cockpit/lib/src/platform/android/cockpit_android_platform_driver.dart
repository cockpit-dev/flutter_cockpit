import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../capture/cockpit_adb_capture_adapter.dart';
import '../../recording/cockpit_adb_recording_adapter.dart';
import '../../session/cockpit_android_remote_session_launcher.dart';
import '../../session/cockpit_remote_session_launch_options.dart';
import '../../session/cockpit_remote_session_handle.dart';
import '../cockpit_device_lifecycle_driver.dart';
import '../cockpit_evidence_driver.dart';
import '../cockpit_platform_driver.dart';

final class CockpitAndroidPlatformDriver
    implements
        CockpitPlatformDriver,
        CockpitDeviceLifecycleDriver,
        CockpitEvidenceDriver {
  CockpitAndroidPlatformDriver({
    required String deviceId,
    CockpitAndroidRemoteSessionLauncher? launcher,
    CockpitAdbCaptureAdapter? captureAdapter,
    CockpitAdbRecordingAdapter? recordingAdapter,
  }) : _deviceId = deviceId,
       _launcher = launcher ?? CockpitAndroidRemoteSessionLauncher(),
       _captureAdapter =
           captureAdapter ?? CockpitAdbCaptureAdapter(deviceId: deviceId),
       _recordingAdapter =
           recordingAdapter ?? CockpitAdbRecordingAdapter(deviceId: deviceId);

  final String _deviceId;
  final CockpitAndroidRemoteSessionLauncher _launcher;
  final CockpitAdbCaptureAdapter _captureAdapter;
  final CockpitAdbRecordingAdapter _recordingAdapter;

  @override
  String get platform => 'android';

  String get deviceId => _deviceId;

  @override
  CockpitAdbCaptureAdapter get captureAdapter => _captureAdapter;

  @override
  CockpitAdbRecordingAdapter get recordingAdapter => _recordingAdapter;

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
    return CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.flutterApp,
      surfaceKinds: <CockpitSurfaceKind>{
        CockpitSurfaceKind.flutterSemantic,
        CockpitSurfaceKind.nativeUi,
        CockpitSurfaceKind.systemUi,
        CockpitSurfaceKind.deviceShell,
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
        CockpitActionCapability.pressBack,
        CockpitActionCapability.pressHome,
        CockpitActionCapability.openNotifications,
        CockpitActionCapability.captureScreenshot,
        CockpitActionCapability.startRecording,
        CockpitActionCapability.stopRecording,
        CockpitActionCapability.readLogs,
        CockpitActionCapability.collectCrashInfo,
        CockpitActionCapability.pushFile,
        CockpitActionCapability.pullFile,
        CockpitActionCapability.runShell,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        CockpitEvidenceCapability.flutterScreenshot,
        CockpitEvidenceCapability.nativeScreenshot,
        CockpitEvidenceCapability.screenRecording,
        CockpitEvidenceCapability.appLogs,
        CockpitEvidenceCapability.deviceLogs,
        CockpitEvidenceCapability.runtimeErrors,
        CockpitEvidenceCapability.crashReports,
        CockpitEvidenceCapability.networkSignals,
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
