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
    String appId = 'dev.cockpit.desktop.linux',
    CockpitLinuxRemoteSessionLauncher? launcher,
    CockpitLinuxCaptureAdapter? captureAdapter,
    CockpitLinuxRecordingAdapter? recordingAdapter,
  })  : _launcher = launcher ?? CockpitLinuxRemoteSessionLauncher(),
        _captureAdapter =
            captureAdapter ?? CockpitLinuxCaptureAdapter(appId: appId),
        _recordingAdapter =
            recordingAdapter ?? CockpitLinuxRecordingAdapter(appId: appId);

  final CockpitLinuxRemoteSessionLauncher _launcher;
  final CockpitLinuxCaptureAdapter _captureAdapter;
  final CockpitLinuxRecordingAdapter _recordingAdapter;

  @override
  String get platform => 'linux';

  @override
  CockpitLinuxCaptureAdapter get captureAdapter => _captureAdapter;

  @override
  CockpitLinuxRecordingAdapter get recordingAdapter => _recordingAdapter;

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
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
        CockpitActionCapability.captureScreenshot,
        CockpitActionCapability.startRecording,
        CockpitActionCapability.stopRecording,
        CockpitActionCapability.readLogs,
        CockpitActionCapability.runShell,
      },
      evidenceCapabilities: <CockpitEvidenceCapability>{
        CockpitEvidenceCapability.windowCapture,
        CockpitEvidenceCapability.screenRecording,
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
