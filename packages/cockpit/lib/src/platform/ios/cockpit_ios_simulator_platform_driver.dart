import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../../capture/cockpit_simctl_capture_adapter.dart';
import '../../recording/cockpit_simctl_recording_adapter.dart';
import '../../session/cockpit_ios_simulator_remote_session_launcher.dart';
import '../../session/cockpit_remote_session_handle.dart';
import '../../session/cockpit_remote_session_launch_options.dart';
import '../../session/cockpit_session_process_runner.dart';
import '../cockpit_device_lifecycle_driver.dart';
import '../cockpit_evidence_driver.dart';
import '../cockpit_platform_driver.dart';

typedef CockpitIosSimulatorShellProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

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
    CockpitIosSimulatorShellProcessRunner? processRunner,
    Duration shellProbeTimeout = const Duration(seconds: 2),
  }) : _deviceId = deviceId,
       _launcher = launcher ?? CockpitIosSimulatorRemoteSessionLauncher(),
       _captureAdapter =
           captureAdapter ?? CockpitSimctlCaptureAdapter(deviceId: deviceId),
       _recordingAdapter =
           recordingAdapter ??
           CockpitSimctlRecordingAdapter(deviceId: deviceId),
       _processRunner = processRunner ?? _runShellProcess,
       _shellProbeTimeout = shellProbeTimeout;

  final String _deviceId;
  final CockpitIosSimulatorRemoteSessionLauncher _launcher;
  final CockpitSimctlCaptureAdapter _captureAdapter;
  final CockpitSimctlRecordingAdapter _recordingAdapter;
  final CockpitIosSimulatorShellProcessRunner _processRunner;
  final Duration _shellProbeTimeout;
  late final Future<bool> _shellAvailable = _probeShellAvailability();
  String? _shellProbeFailureReason;

  @override
  String get platform => 'ios';

  String get deviceId => _deviceId;

  @override
  CockpitSimctlCaptureAdapter get captureAdapter => _captureAdapter;

  @override
  CockpitSimctlRecordingAdapter get recordingAdapter => _recordingAdapter;

  /// A stable diagnostic for callers that need to explain why shell support
  /// was omitted from the capability snapshot.
  String? get shellProbeFailureReason => _shellProbeFailureReason;

  @override
  Future<CockpitCapabilityProfile> describeCapabilities() async {
    final shellAvailable = await _shellAvailable;
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
        if (shellAvailable) CockpitActionCapability.runShell,
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

  Future<bool> _probeShellAvailability() async {
    const executable = 'xcrun';
    final arguments = <String>[
      'simctl',
      'spawn',
      _deviceId,
      '/bin/sh',
      '-lc',
      'true',
    ];

    try {
      final result = await _processRunner(
        executable,
        arguments,
      ).timeout(_shellProbeTimeout);
      if (result.exitCode == 0) {
        return true;
      }
      _shellProbeFailureReason =
          'simulator shell probe failed for device $_deviceId '
          'with exit code ${result.exitCode}.';
    } on TimeoutException {
      _shellProbeFailureReason =
          'simulator shell probe timed out for device $_deviceId.';
    } on Object catch (error) {
      _shellProbeFailureReason =
          'simulator shell probe failed for device $_deviceId: $error';
    }
    return false;
  }

  static Future<ProcessResult> _runShellProcess(
    String executable,
    List<String> arguments,
  ) {
    return cockpitRunProcessWithTimeout(
      executable,
      arguments,
      timeout: const Duration(seconds: 2),
    );
  }

  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) {
    return _launcher.launch(options);
  }
}
