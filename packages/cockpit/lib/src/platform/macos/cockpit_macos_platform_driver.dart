import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../../capture/cockpit_macos_capture_adapter.dart';
import '../../recording/cockpit_macos_recording_adapter.dart';
import '../../session/cockpit_macos_remote_session_launcher.dart';
import '../../session/cockpit_remote_session_handle.dart';
import '../../session/cockpit_remote_session_launch_options.dart';
import '../cockpit_device_lifecycle_driver.dart';
import '../cockpit_evidence_driver.dart';
import '../cockpit_platform_driver.dart';

final class CockpitMacosPlatformDriver
    implements
        CockpitPlatformDriver,
        CockpitDeviceLifecycleDriver,
        CockpitEvidenceDriver {
  CockpitMacosPlatformDriver({
    String? appId,
    CockpitMacosRemoteSessionLauncher? launcher,
    CockpitMacosCaptureAdapter? captureAdapter,
    bool enableDefaultCaptureAdapter = true,
    CockpitMacosRecordingAdapter? recordingAdapter,
    bool enableDefaultRecordingAdapter = true,
  }) : _launcher = launcher ?? CockpitMacosRemoteSessionLauncher(),
       _captureAdapter =
           captureAdapter ??
           ((!enableDefaultCaptureAdapter || appId == null || appId.isEmpty)
               ? null
               : CockpitMacosCaptureAdapter(appId: appId)),
       _recordingAdapter =
           recordingAdapter ??
           ((!enableDefaultRecordingAdapter || appId == null || appId.isEmpty)
               ? null
               : CockpitMacosRecordingAdapter(appId: appId));

  final CockpitMacosRemoteSessionLauncher _launcher;
  final CockpitMacosCaptureAdapter? _captureAdapter;
  final CockpitMacosRecordingAdapter? _recordingAdapter;

  @override
  String get platform => 'macos';

  @override
  CockpitMacosCaptureAdapter? get captureAdapter => _captureAdapter;

  @override
  CockpitMacosRecordingAdapter? get recordingAdapter => _recordingAdapter;

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
    final supportsWindowCapture = _captureAdapter != null;
    final supportsScreenRecording = _recordingAdapter != null;
    return CockpitCapabilityProfile(
      targetKind: CockpitTargetKind.desktopApp,
      surfaceKinds: <CockpitSurfaceKind>{
        CockpitSurfaceKind.desktopWindow,
        CockpitSurfaceKind.systemUi,
        CockpitSurfaceKind.hostShell,
      },
      actionCapabilities: <CockpitActionCapability>{
        CockpitActionCapability.launchApp,
        CockpitActionCapability.stopApp,
        CockpitActionCapability.focusApp,
        CockpitActionCapability.tap,
        CockpitActionCapability.typeText,
        if (supportsWindowCapture) CockpitActionCapability.captureScreenshot,
        if (supportsScreenRecording) CockpitActionCapability.startRecording,
        if (supportsScreenRecording) CockpitActionCapability.stopRecording,
        CockpitActionCapability.readLogs,
        CockpitActionCapability.runShell,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        if (supportsWindowCapture) CockpitEvidenceCapability.windowCapture,
        if (supportsScreenRecording) CockpitEvidenceCapability.screenRecording,
        CockpitEvidenceCapability.appLogs,
        CockpitEvidenceCapability.runtimeErrors,
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
