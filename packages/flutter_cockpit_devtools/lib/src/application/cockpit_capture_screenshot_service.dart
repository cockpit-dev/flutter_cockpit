import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_app_handle.dart';
import 'cockpit_interactive_result_profile.dart';
import 'cockpit_run_command_service.dart';

final class CockpitCaptureScreenshotRequest {
  const CockpitCaptureScreenshotRequest({
    this.appId,
    this.app,
    this.appHandlePath,
    this.baseUri,
    this.androidDeviceId,
    this.name = 'screenshot',
    this.reason = CockpitScreenshotReason.acceptance,
    this.includeSnapshot = false,
    this.attachToStep = true,
    this.resultProfile = const CockpitInteractiveResultProfile.standard(),
    this.defaultCommandTimeout = const Duration(seconds: 30),
  });

  final String? appId;
  final CockpitAppHandle? app;
  final String? appHandlePath;
  final Uri? baseUri;
  final String? androidDeviceId;
  final String name;
  final CockpitScreenshotReason reason;
  final bool includeSnapshot;
  final bool attachToStep;
  final CockpitInteractiveResultProfile resultProfile;
  final Duration defaultCommandTimeout;
}

typedef CockpitCaptureScreenshotResult = CockpitRunCommandResult;

typedef CockpitCaptureScreenshotRunCommand =
    Future<CockpitRunCommandResult> Function(CockpitRunCommandRequest request);

final class CockpitCaptureScreenshotService {
  CockpitCaptureScreenshotService({
    CockpitRunCommandService? runCommandService,
    CockpitCaptureScreenshotRunCommand? runCommand,
  }) : _runCommand =
           runCommand ?? (runCommandService ?? CockpitRunCommandService()).run;

  final CockpitCaptureScreenshotRunCommand _runCommand;

  Future<CockpitCaptureScreenshotResult> capture(
    CockpitCaptureScreenshotRequest request,
  ) {
    final trimmedName = request.name.trim();
    final name = trimmedName.isEmpty ? 'screenshot' : trimmedName;
    return _runCommand(
      CockpitRunCommandRequest(
        appId: request.appId,
        app: request.app,
        appHandlePath: request.appHandlePath,
        baseUri: request.baseUri,
        androidDeviceId: request.androidDeviceId,
        command: CockpitCommand(
          commandId: 'capture-screenshot',
          commandType: CockpitCommandType.captureScreenshot,
          screenshotRequest: CockpitScreenshotRequest(
            reason: request.reason,
            name: name,
            includeSnapshot: request.includeSnapshot,
            attachToStep: request.attachToStep,
          ),
        ),
        resultProfile: request.resultProfile,
        defaultCommandTimeout: request.defaultCommandTimeout,
      ),
    );
  }
}
