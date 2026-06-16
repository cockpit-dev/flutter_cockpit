import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../capture/cockpit_linux_capture_adapter.dart';
import '../../recording/cockpit_linux_recording_adapter.dart';
import '../../session/cockpit_linux_remote_session_launcher.dart';
import '../../session/cockpit_remote_session_handle.dart';
import '../../session/cockpit_remote_session_launch_options.dart';
import '../cockpit_device_lifecycle_driver.dart';
import '../cockpit_evidence_driver.dart';
import '../cockpit_platform_driver.dart';

final class CockpitLinuxPlatformDriver
    implements
        CockpitPlatformDriver,
        CockpitDeviceLifecycleDriver,
        CockpitEvidenceDriver {
  CockpitLinuxPlatformDriver({
    String? appId,
    int? processId,
    CockpitLinuxRemoteSessionLauncher? launcher,
    CockpitLinuxCaptureAdapter? captureAdapter,
    bool enableDefaultCaptureAdapter = true,
    CockpitLinuxRecordingAdapter? recordingAdapter,
    bool enableDefaultRecordingAdapter = true,
  }) : _launcher = launcher ?? CockpitLinuxRemoteSessionLauncher(),
       _captureAdapter =
           captureAdapter ??
           ((!enableDefaultCaptureAdapter || appId == null || appId.isEmpty)
               ? null
               : CockpitLinuxCaptureAdapter(
                   appId: appId,
                   processId: processId,
                 )),
       _recordingAdapter =
           recordingAdapter ??
           ((!enableDefaultRecordingAdapter || appId == null || appId.isEmpty)
               ? null
               : CockpitLinuxRecordingAdapter(
                   appId: appId,
                   processId: processId,
                 ));

  final CockpitLinuxRemoteSessionLauncher _launcher;
  final CockpitLinuxCaptureAdapter? _captureAdapter;
  final CockpitLinuxRecordingAdapter? _recordingAdapter;

  @override
  String get platform => 'linux';

  @override
  CockpitLinuxCaptureAdapter? get captureAdapter => _captureAdapter;

  @override
  CockpitLinuxRecordingAdapter? get recordingAdapter => _recordingAdapter;

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
