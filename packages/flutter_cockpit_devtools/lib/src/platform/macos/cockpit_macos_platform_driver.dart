import 'package:flutter_cockpit/flutter_cockpit.dart';

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
    String appId = 'dev.cockpit.desktop.macos',
    CockpitMacosRemoteSessionLauncher? launcher,
    CockpitMacosCaptureAdapter? captureAdapter,
    CockpitMacosRecordingAdapter? recordingAdapter,
  })  : _launcher = launcher ?? CockpitMacosRemoteSessionLauncher(),
        _captureAdapter =
            captureAdapter ?? CockpitMacosCaptureAdapter(appId: appId),
        _recordingAdapter =
            recordingAdapter ?? CockpitMacosRecordingAdapter(appId: appId);

  final CockpitMacosRemoteSessionLauncher _launcher;
  final CockpitMacosCaptureAdapter _captureAdapter;
  final CockpitMacosRecordingAdapter _recordingAdapter;

  @override
  String get platform => 'macos';

  @override
  CockpitMacosCaptureAdapter get captureAdapter => _captureAdapter;

  @override
  CockpitMacosRecordingAdapter get recordingAdapter => _recordingAdapter;

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
