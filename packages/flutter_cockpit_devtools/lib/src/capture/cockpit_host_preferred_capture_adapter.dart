import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_capture_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';

final class CockpitHostPreferredCaptureAdapter
    implements CockpitCaptureAdapter {
  CockpitHostPreferredCaptureAdapter({
    required CockpitCaptureAdapter remoteAdapter,
    required CockpitCaptureAdapter hostAcceptanceAdapter,
    required CockpitRemoteSessionClient client,
  })  : _remoteAdapter = remoteAdapter,
        _hostAcceptanceAdapter = hostAcceptanceAdapter,
        _client = client;

  final CockpitCaptureAdapter _remoteAdapter;
  final CockpitCaptureAdapter _hostAcceptanceAdapter;
  final CockpitRemoteSessionClient _client;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    final request = command.screenshotRequest;
    if (request == null ||
        request.reason != CockpitScreenshotReason.acceptance) {
      return _remoteAdapter.capture(command);
    }

    await _client.waitForUiIdle();
    final execution = await _hostAcceptanceAdapter.capture(command);
    if (!execution.result.success || !request.includeSnapshot) {
      return execution;
    }

    try {
      final snapshot = await _client.readSnapshot(
        options: request.snapshotOptions ??
            _defaultSnapshotOptionsForReason(request.reason),
      );
      return CockpitCommandExecution(
        result: CockpitCommandResult(
          success: execution.result.success,
          commandId: execution.result.commandId,
          commandType: execution.result.commandType,
          locatorResolution: execution.result.locatorResolution,
          durationMs: execution.result.durationMs,
          artifacts: execution.result.artifacts,
          snapshot: snapshot.toJson(),
          requestedCaptureProfile: execution.result.requestedCaptureProfile,
          resolvedCaptureKind: execution.result.resolvedCaptureKind,
          usedCaptureFallback: execution.result.usedCaptureFallback,
          degradationReason: execution.result.degradationReason,
          error: execution.result.error,
        ),
        artifactPayloads: execution.artifactPayloads,
        artifactSourcePaths: execution.artifactSourcePaths,
        runtimeSteps: execution.runtimeSteps,
      );
    } on Object {
      return execution;
    }
  }

  CockpitSnapshotOptions _defaultSnapshotOptionsForReason(
    CockpitScreenshotReason reason,
  ) {
    return switch (reason) {
      CockpitScreenshotReason.assertionFailure =>
        const CockpitSnapshotOptions.investigate(),
      CockpitScreenshotReason.baseline =>
        const CockpitSnapshotOptions.baseline(),
      CockpitScreenshotReason.acceptance =>
        const CockpitSnapshotOptions.investigate(),
      CockpitScreenshotReason.beforeAction ||
      CockpitScreenshotReason.afterAction =>
        const CockpitSnapshotOptions.live(),
    };
  }
}
