import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../../capture/cockpit_windows_capture_adapter.dart';
import '../../recording/cockpit_windows_recording_adapter.dart';
import '../../session/cockpit_remote_session_handle.dart';
import '../../session/cockpit_remote_session_launch_options.dart';
import '../../session/cockpit_windows_remote_session_launcher.dart';
import '../cockpit_device_lifecycle_driver.dart';
import '../cockpit_evidence_driver.dart';
import '../cockpit_platform_driver.dart';

final class CockpitWindowsPlatformDriver
    implements
        CockpitPlatformDriver,
        CockpitDeviceLifecycleDriver,
        CockpitEvidenceDriver {
  CockpitWindowsPlatformDriver({
    String appId = 'dev.cockpit.desktop.windows',
    CockpitWindowsRemoteSessionLauncher? launcher,
    CockpitWindowsCaptureAdapter? captureAdapter,
    CockpitWindowsRecordingAdapter? recordingAdapter,
  })  : _launcher = launcher ?? CockpitWindowsRemoteSessionLauncher(),
        _captureAdapter =
            captureAdapter ?? CockpitWindowsCaptureAdapter(appId: appId),
        _recordingAdapter =
            recordingAdapter ?? CockpitWindowsRecordingAdapter(appId: appId);

  final CockpitWindowsRemoteSessionLauncher _launcher;
  final CockpitWindowsCaptureAdapter _captureAdapter;
  final CockpitWindowsRecordingAdapter _recordingAdapter;

  @override
  String get platform => 'windows';

  @override
  CockpitWindowsCaptureAdapter get captureAdapter => _captureAdapter;

  @override
  CockpitWindowsRecordingAdapter get recordingAdapter => _recordingAdapter;

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
