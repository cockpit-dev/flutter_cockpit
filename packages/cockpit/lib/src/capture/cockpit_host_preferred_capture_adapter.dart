import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_capture_adapter.dart';
import '../remote/cockpit_remote_session_client.dart';
import 'cockpit_host_capture_adapter.dart';

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
    } on Object catch (error) {
      if (!await _remoteScreenshotFallbackAvailable()) {
        return cockpitFailedCaptureExecution(
          command: command,
          durationMs: 0,
          message: 'Host screenshot capture threw before remote fallback.',
          details: <String, Object?>{
            'fallbackSkipped': 'remoteCaptureUnsupported',
            'error': error.toString(),
          },
        );
      }
      try {
        final fallbackExecution = await _remoteAdapter.capture(command);
        return _withFallbackMetadata(
          fallbackExecution,
          degradationReason: 'hostCaptureThrew',
        );
      } on Object catch (fallbackError) {
        return _withFallbackMetadata(
          cockpitFailedCaptureExecution(
            command: command,
            durationMs: 0,
            message: 'Host screenshot capture threw and remote fallback threw.',
            details: <String, Object?>{
              'hostError': error.toString(),
              'remoteFallbackError': fallbackError.toString(),
            },
          ),
          degradationReason:
              'hostCaptureThrew; remoteFallbackThrew: ${fallbackError.toString()}',
        );
      }
    }
    if (!execution.result.success) {
      if (!await _remoteScreenshotFallbackAvailable()) {
        return execution;
      }
      final CockpitCommandExecution fallbackExecution;
      try {
        fallbackExecution = await _remoteAdapter.capture(command);
      } on Object catch (fallbackError) {
        return _withFallbackMetadata(
          execution,
          degradationReason:
              'hostCaptureFailed; remoteFallbackThrew: ${fallbackError.toString()}',
        );
      }
      if (!fallbackExecution.result.success) {
        return _withFallbackMetadata(
          execution,
          degradationReason:
              'hostCaptureFailed; remoteFallbackFailed: ${_failureSummary(fallbackExecution.result)}',
        );
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

  String _failureSummary(CockpitCommandResult result) {
    final error = result.error;
    if (error != null) {
      return error.message;
    }
    final degradationReason = result.degradationReason;
    if (degradationReason != null && degradationReason.isNotEmpty) {
      return degradationReason;
    }
    return 'capture returned success=false';
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

  Future<bool> _remoteScreenshotFallbackAvailable() async {
    try {
      final status = await _client.readStatus();
      return status.capabilities.supportsFlutterViewCapture &&
          status.capabilities.supportedCommands.contains(
            CockpitCommandType.captureScreenshot,
          );
    } on Object {
      return false;
    }
  }
}
