import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_capture_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';

final class CockpitHostPreferredCaptureAdapter
    implements CockpitCaptureAdapter {
  CockpitHostPreferredCaptureAdapter({
    required CockpitCaptureAdapter remoteAdapter,
    required CockpitCaptureAdapter hostAcceptanceAdapter,
    required CockpitRemoteSessionClient client,
    Duration preCaptureIdleTimeout = const Duration(milliseconds: 600),
  }) : _remoteAdapter = remoteAdapter,
       _hostAcceptanceAdapter = hostAcceptanceAdapter,
       _client = client,
       _preCaptureIdleTimeout = preCaptureIdleTimeout;

  final CockpitCaptureAdapter _remoteAdapter;
  final CockpitCaptureAdapter _hostAcceptanceAdapter;
  final CockpitRemoteSessionClient _client;
  final Duration _preCaptureIdleTimeout;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    final request = command.screenshotRequest;
    if (request == null) {
      return _remoteAdapter.capture(command);
    }

    await _client.waitForUiIdle(timeout: _preCaptureIdleTimeout);
    final CockpitCommandExecution execution;
    try {
      execution = await _hostAcceptanceAdapter.capture(command);
    } on Object {
      final fallbackExecution = await _remoteAdapter.capture(command);
      return _withFallbackMetadata(
        fallbackExecution,
        degradationReason: 'hostCaptureThrew',
      );
    }
    if (!execution.result.success) {
      final fallbackExecution = await _remoteAdapter.capture(command);
      if (!fallbackExecution.result.success) {
        return execution;
      }
      return _withFallbackMetadata(
        fallbackExecution,
        degradationReason: 'hostCaptureFailed',
      );
    }
    if (!request.includeSnapshot) {
      return execution;
    }

    try {
      final snapshot = await _client.readSnapshot(
        options:
            request.snapshotOptions ??
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

  CockpitCommandExecution _withFallbackMetadata(
    CockpitCommandExecution execution, {
    required String degradationReason,
  }) {
    final result = execution.result;
    return CockpitCommandExecution(
      result: CockpitCommandResult(
        success: result.success,
        commandId: result.commandId,
        commandType: result.commandType,
        locatorResolution: result.locatorResolution,
        durationMs: result.durationMs,
        artifacts: result.artifacts,
        snapshot: result.snapshot,
        requestedCaptureProfile: result.requestedCaptureProfile,
        resolvedCaptureKind: result.resolvedCaptureKind,
        usedCaptureFallback: true,
        degradationReason: degradationReason,
        error: result.error,
      ),
      artifactPayloads: execution.artifactPayloads,
      artifactSourcePaths: execution.artifactSourcePaths,
      runtimeSteps: execution.runtimeSteps,
    );
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
