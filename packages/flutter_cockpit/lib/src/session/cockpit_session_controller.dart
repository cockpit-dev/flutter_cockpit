// ignore_for_file: deprecated_member_use

import '../context/cockpit_context_bundle.dart';
import '../capture/cockpit_capture_kind.dart';
import '../capture/cockpit_capture_profile.dart';
import '../control/cockpit_command_status.dart';
import '../control/cockpit_command.dart';
import '../control/cockpit_command_result.dart';
import '../control/cockpit_command_type.dart';
import '../control/cockpit_locator.dart';
import '../control/cockpit_locator_resolution.dart';
import '../model/cockpit_artifact_ref.dart';
import '../model/cockpit_environment.dart';
import '../model/cockpit_observation.dart';
import '../model/cockpit_run_manifest.dart';
import '../model/cockpit_step_record.dart';
import '../model/cockpit_task_status.dart';
import '../network/cockpit_network_entry.dart';
import '../runtime/cockpit_runtime_event.dart';
import '../runtime/cockpit_snapshot.dart';
import '../runtime/cockpit_snapshot_options.dart';
import '../recording/cockpit_recording_purpose.dart';
import 'cockpit_session.dart';

typedef CockpitTimestampProvider = DateTime Function();

final class CockpitSessionController {
  CockpitSessionController({
    required String sessionId,
    required String taskId,
    required String platform,
    CockpitTimestampProvider? now,
  })  : _now = now ?? _systemNow,
        _session = CockpitSession(
          sessionId: sessionId,
          taskId: taskId,
          platform: platform,
          startedAt: (now ?? _systemNow)().toUtc(),
        );

  final CockpitTimestampProvider _now;
  final CockpitSession _session;
  final List<CockpitStepRecord> _steps = <CockpitStepRecord>[];
  bool _isClosed = false;

  CockpitSession get session => _session;

  void recordStep({
    required String actionType,
    required Map<String, Object?> actionArgs,
    CockpitObservation? observation,
    CockpitSnapshot? snapshot,
    List<CockpitArtifactRef> artifactRefs = const [],
    CockpitCommandType? commandType,
    CockpitLocator? locator,
    CockpitLocatorResolution? locatorResolution,
    int? durationMs,
    CockpitCommandStatus? status,
    CockpitCaptureProfile? requestedCaptureProfile,
    CockpitCaptureKind? resolvedCaptureKind,
    bool usedCaptureFallback = false,
    String? degradationReason,
    List<CockpitArtifactRef> captureRefs = const [],
  }) {
    _ensureOpen();

    _steps.add(
      CockpitStepRecord(
        index: _steps.length,
        actionType: actionType,
        actionArgs: actionArgs,
        observedAt: _now().toUtc(),
        observation: observation,
        snapshot: snapshot,
        artifactRefs: artifactRefs,
        commandType: commandType,
        locator: locator,
        locatorResolution: locatorResolution,
        durationMs: durationMs,
        status: status,
        requestedCaptureProfile: requestedCaptureProfile,
        resolvedCaptureKind: resolvedCaptureKind,
        usedCaptureFallback: usedCaptureFallback,
        degradationReason: degradationReason,
        captureRefs: captureRefs,
      ),
    );
  }

  void recordCommandResult(
    CockpitCommand command,
    CockpitCommandResult result,
  ) {
    final rawSnapshot = result.snapshot == null
        ? null
        : CockpitSnapshot.fromJson(result.snapshot!);
    final snapshot = rawSnapshot == null
        ? null
        : _normalizeSnapshotForBundle(rawSnapshot, command: command);
    final observation = snapshot == null
        ? null
        : CockpitObservation(
            routeName: snapshot.routeName,
            interactiveElements: snapshot.visibleTargets
                .map((target) => target.displayLabel)
                .whereType<String>()
                .toList(growable: false),
            phase: result.success
                ? CockpitObservationPhase.afterAction
                : CockpitObservationPhase.failure,
            diagnosticLevel: snapshot.diagnosticLevel,
            truncated: snapshot.truncated,
            diagnosticsArtifactRef: snapshot.diagnosticsArtifactRef,
            summary: snapshot.summary,
          );

    recordStep(
      actionType: command.commandType.name,
      actionArgs: <String, Object?>{
        'commandId': command.commandId,
        ...command.parameters,
      },
      observation: observation,
      snapshot: snapshot,
      artifactRefs: <CockpitArtifactRef>[
        ...result.artifacts,
        if (snapshot?.diagnosticsArtifactRef != null)
          snapshot!.diagnosticsArtifactRef!,
      ],
      commandType: command.commandType,
      locator: command.locator,
      locatorResolution: result.locatorResolution,
      durationMs: result.durationMs,
      status: result.success
          ? CockpitCommandStatus.succeeded
          : CockpitCommandStatus.failed,
      requestedCaptureProfile: result.requestedCaptureProfile,
      resolvedCaptureKind: result.resolvedCaptureKind,
      usedCaptureFallback: result.usedCaptureFallback,
      degradationReason: result.degradationReason,
      captureRefs: result.artifacts
          .where((artifact) => artifact.role == 'screenshot')
          .toList(growable: false),
    );
  }

  void importStepRecords(Iterable<CockpitStepRecord> steps) {
    for (final step in steps) {
      _ensureOpen();
      _steps.add(
        CockpitStepRecord(
          index: _steps.length,
          actionType: step.actionType,
          actionArgs: step.actionArgs,
          observedAt: step.observedAt,
          observation: step.observation,
          snapshot: step.snapshot,
          artifactRefs: step.artifactRefs,
          commandType: step.commandType,
          locator: step.locator,
          locatorResolution: step.locatorResolution,
          durationMs: step.durationMs,
          status: step.status,
          requestedCaptureProfile: step.requestedCaptureProfile,
          resolvedCaptureKind: step.resolvedCaptureKind,
          usedCaptureFallback: step.usedCaptureFallback,
          degradationReason: step.degradationReason,
          captureRefs: step.captureRefs,
        ),
      );
    }
  }

  CockpitContextBundle finish({
    required CockpitEnvironment environment,
    List<String> capabilitiesUsed = const [],
  }) {
    return _close(
      environment: environment,
      status: CockpitTaskStatus.completed,
      capabilitiesUsed: capabilitiesUsed,
    );
  }

  CockpitContextBundle finishWithFailure({
    required CockpitEnvironment environment,
    required String failureSummary,
    List<String> capabilitiesUsed = const [],
  }) {
    return _close(
      environment: environment,
      status: CockpitTaskStatus.failed,
      failureSummary: failureSummary,
      capabilitiesUsed: capabilitiesUsed,
    );
  }

  CockpitContextBundle _close({
    required CockpitEnvironment environment,
    required CockpitTaskStatus status,
    required List<String> capabilitiesUsed,
    String? failureSummary,
  }) {
    _ensureOpen();
    _isClosed = true;

    final artifactRefs = <CockpitArtifactRef>{
      ..._steps.expand((step) => step.artifactRefs),
      ..._steps.expand((step) => step.captureRefs),
    };
    final screenshotRefs = _collectArtifactPaths(role: 'screenshot');
    final primaryScreenshotRef = _selectPrimaryScreenshotRef();
    final recordingRefs = artifactRefs
        .where((artifact) => artifact.role == 'recording')
        .map((artifact) => artifact.relativePath)
        .toList(growable: false);
    final primaryRecordingRef = recordingRefs.firstWhere(
      (_) => true,
      orElse: () => '',
    );
    final commandCount =
        _steps.where((step) => step.commandType != null).length;
    final screenshotCount = _steps.fold<int>(
      0,
      (count, step) => count + step.captureRefs.length,
    );
    final nativeScreenshotCount = _steps.fold<int>(
      0,
      (count, step) =>
          count +
          (step.resolvedCaptureKind == CockpitCaptureKind.nativeAcceptance
              ? step.captureRefs.length
              : 0),
    );
    final flutterScreenshotCount = _steps.fold<int>(
      0,
      (count, step) =>
          count +
          (step.resolvedCaptureKind == CockpitCaptureKind.flutterView
              ? step.captureRefs.length
              : 0),
    );
    final deliveryArtifactsReady = _steps.any(
      (step) =>
          step.captureRefs.isNotEmpty &&
          (step.requestedCaptureProfile == CockpitCaptureProfile.acceptance ||
              step.requestedCaptureProfile ==
                  CockpitCaptureProfile.nativePreferred),
    );
    final recordingCount = recordingRefs.length;
    final nativeRecordingCount = recordingRefs.length;
    final deliveryVideoReady = _steps.any(
      (step) =>
          step.artifactRefs.any((artifact) => artifact.role == 'recording') &&
          step.actionArgs['recordingPurpose'] ==
              CockpitRecordingPurpose.acceptance.name,
    );
    final failureCount = _steps
        .where((step) => step.status == CockpitCommandStatus.failed)
        .length;
    final runtimeSummary = _summarizeRuntimeActivity();
    final runtimeEventCount = runtimeSummary?.totalEntryCount ?? 0;
    final runtimeErrorCount = runtimeSummary?.errorCount ?? 0;
    final runtimeWarningCount = runtimeSummary?.warningCount ?? 0;
    final effectiveStatus =
        status == CockpitTaskStatus.completed && runtimeErrorCount > 0
            ? CockpitTaskStatus.failed
            : status;
    final effectiveFailureSummary =
        effectiveStatus == CockpitTaskStatus.failed &&
                failureSummary == null &&
                runtimeErrorCount > 0
            ? 'Runtime errors were captured during the task.'
            : failureSummary;
    final manifest = CockpitRunManifest(
      sessionId: _session.sessionId,
      taskId: _session.taskId,
      platform: _session.platform,
      status: effectiveStatus,
      startedAt: _session.startedAt,
      finishedAt: _now().toUtc(),
      artifactRefs: artifactRefs.toList(growable: false),
      failureSummary: effectiveFailureSummary,
      capabilitiesUsed: capabilitiesUsed,
      commandCount: commandCount,
      screenshotCount: screenshotCount,
      failureCount: failureCount,
      nativeScreenshotCount: nativeScreenshotCount,
      flutterScreenshotCount: flutterScreenshotCount,
      deliveryArtifactsReady: deliveryArtifactsReady,
      recordingCount: recordingCount,
      nativeRecordingCount: nativeRecordingCount,
      deliveryVideoReady: deliveryVideoReady,
      runtimeEventCount: runtimeEventCount,
      runtimeErrorCount: runtimeErrorCount,
      runtimeWarningCount: runtimeWarningCount,
    );
    final observations = _steps
        .map((step) => step.observation)
        .whereType<CockpitObservation>()
        .toList(growable: false);
    final handoff = <String, Object?>{
      'sessionId': _session.sessionId,
      'taskId': _session.taskId,
      'platform': _session.platform,
      'status': effectiveStatus.name,
      'stepCount': _steps.length,
      'capabilitiesUsed': capabilitiesUsed,
      'commandCount': commandCount,
      'screenshotCount': screenshotCount,
      'failureCount': failureCount,
      'nativeScreenshotCount': nativeScreenshotCount,
      'flutterScreenshotCount': flutterScreenshotCount,
      'deliveryArtifactsReady': deliveryArtifactsReady,
      'recordingCount': recordingCount,
      'nativeRecordingCount': nativeRecordingCount,
      'deliveryVideoReady': deliveryVideoReady,
      'runtimeEventCount': runtimeEventCount,
      'runtimeErrorCount': runtimeErrorCount,
      'runtimeWarningCount': runtimeWarningCount,
      if (effectiveFailureSummary != null)
        'failureSummary': effectiveFailureSummary,
    };

    return CockpitContextBundle(
      manifest: manifest,
      environment: environment,
      steps: _steps,
      observations: observations,
      acceptanceMarkdown: _buildAcceptanceMarkdown(
        status: effectiveStatus,
        failureSummary: effectiveFailureSummary,
        runtimeSummary: runtimeSummary,
      ),
      handoff: handoff,
      delivery: <String, Object?>{
        'summary': effectiveStatus == CockpitTaskStatus.completed
            ? 'Ready for user delivery'
            : 'Delivery blocked by task failure',
        'primaryScreenshotRef':
            primaryScreenshotRef.isEmpty ? null : primaryScreenshotRef,
        'attachmentRefs': screenshotRefs,
        'deliveryArtifactsReady': deliveryArtifactsReady,
        'primaryRecordingRef':
            primaryRecordingRef.isEmpty ? null : primaryRecordingRef,
        'videoAttachmentRefs': recordingRefs,
        'deliveryVideoReady': deliveryVideoReady,
      },
    );
  }

  List<String> _collectArtifactPaths({required String role}) {
    final paths = <String>[];
    final seenPaths = <String>{};
    for (final step in _steps) {
      for (final artifact in <CockpitArtifactRef>[
        ...step.captureRefs,
        ...step.artifactRefs,
      ]) {
        if (artifact.role != role || !seenPaths.add(artifact.relativePath)) {
          continue;
        }
        paths.add(artifact.relativePath);
      }
    }
    return List.unmodifiable(paths);
  }

  String _selectPrimaryScreenshotRef() {
    for (final step in _steps.reversed) {
      if (step.requestedCaptureProfile != CockpitCaptureProfile.acceptance &&
          step.requestedCaptureProfile !=
              CockpitCaptureProfile.nativePreferred) {
        continue;
      }
      final screenshotRef = _lastArtifactPathForStep(step, role: 'screenshot');
      if (screenshotRef != null) {
        return screenshotRef;
      }
    }
    for (final step in _steps.reversed) {
      final screenshotRef = _lastArtifactPathForStep(step, role: 'screenshot');
      if (screenshotRef != null) {
        return screenshotRef;
      }
    }
    return '';
  }

  String? _lastArtifactPathForStep(
    CockpitStepRecord step, {
    required String role,
  }) {
    for (final artifact in <CockpitArtifactRef>[
      ...step.captureRefs.reversed,
      ...step.artifactRefs.reversed,
    ]) {
      if (artifact.role == role) {
        return artifact.relativePath;
      }
    }
    return null;
  }

  CockpitSnapshot _normalizeSnapshotForBundle(
    CockpitSnapshot snapshot, {
    required CockpitCommand command,
  }) {
    final diagnosticsArtifactRef = snapshot.diagnosticsArtifactRef ??
        _diagnosticsArtifactRefFor(snapshot, command: command);
    if (diagnosticsArtifactRef == null) {
      return snapshot;
    }

    return CockpitSnapshot(
      routeName: snapshot.routeName,
      visibleTargets: snapshot.visibleTargets,
      diagnosticLevel: snapshot.diagnosticLevel,
      truncated: snapshot.truncated,
      diagnosticsArtifactRef: diagnosticsArtifactRef,
      summary: snapshot.summary,
      network: snapshot.network,
      runtime: snapshot.runtime,
    );
  }

  CockpitArtifactRef? _diagnosticsArtifactRefFor(
    CockpitSnapshot snapshot, {
    required CockpitCommand command,
  }) {
    final shouldExternalize =
        snapshot.diagnosticLevel == CockpitSnapshotProfile.forensic ||
            snapshot.truncated;
    if (!shouldExternalize) {
      return null;
    }

    final safeCommandId = _sanitizeForPath(
      command.commandId.isEmpty ? command.commandType.name : command.commandId,
    );
    final stepIndex = _steps.length.toString().padLeft(3, '0');
    return CockpitArtifactRef(
      role: 'diagnostics',
      relativePath:
          'diagnostics/step_${stepIndex}_${safeCommandId}_snapshot.json',
    );
  }

  String _sanitizeForPath(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_');
    return sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  void _ensureOpen() {
    if (_isClosed) {
      throw StateError('Cockpit session is already closed.');
    }
  }

  String _buildAcceptanceMarkdown({
    required CockpitTaskStatus status,
    String? failureSummary,
    _CockpitAcceptanceRuntimeSummary? runtimeSummary,
  }) {
    final recordingRefs = _steps
        .expand((step) => step.artifactRefs)
        .where((artifact) => artifact.role == 'recording')
        .map((artifact) => artifact.relativePath)
        .toList(growable: false);
    final lastRecordingFailure = _steps
        .where((step) => step.actionType == 'recording_failed')
        .map((step) => step.actionArgs['failureReason'] as String?)
        .whereType<String>()
        .lastOrNull;
    final buffer = StringBuffer()
      ..writeln('# Acceptance')
      ..writeln()
      ..writeln('- Session: ${_session.sessionId}')
      ..writeln('- Task: ${_session.taskId}')
      ..writeln('- Platform: ${_session.platform}')
      ..writeln('- Status: ${status.name}')
      ..writeln('- Steps: ${_steps.length}');

    if (failureSummary != null) {
      buffer.writeln('- Failure: $failureSummary');
    }

    buffer.writeln();
    buffer.writeln('## Recording');
    if (recordingRefs.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('- Acceptance video: ${recordingRefs.first}');
      buffer.writeln('- Recording count: ${recordingRefs.length}');
    } else {
      buffer.writeln();
      buffer.writeln('- Recording unavailable');
      if (lastRecordingFailure != null) {
        buffer.writeln('- Recording failure: $lastRecordingFailure');
      }
    }

    final networkSummary = _summarizeNetworkActivity();
    if (networkSummary != null) {
      buffer.writeln();
      buffer.writeln('## Network');
      buffer.writeln();
      buffer.writeln('- Requests captured: ${networkSummary.totalEntryCount}');
      buffer.writeln('- Failures: ${networkSummary.failureCount}');
      if (networkSummary.recentEntries.isNotEmpty) {
        final latest = networkSummary.recentEntries.first;
        buffer.writeln(
          '- Latest request: ${latest.method} ${latest.uri} · ${latest.statusCode ?? 'pending'}',
        );
      }
      if (networkSummary.failingEntries.isNotEmpty) {
        final latestFailure = networkSummary.failingEntries.first;
        buffer.writeln(
          '- Latest failure: ${latestFailure.method} ${latestFailure.uri} · ${latestFailure.statusCode ?? latestFailure.error ?? 'failed'}',
        );
      }
    }

    if (runtimeSummary != null) {
      buffer.writeln();
      buffer.writeln('## Runtime');
      buffer.writeln();
      buffer.writeln('- Events captured: ${runtimeSummary.totalEntryCount}');
      buffer.writeln('- Errors: ${runtimeSummary.errorCount}');
      buffer.writeln('- Warnings: ${runtimeSummary.warningCount}');
      if (runtimeSummary.recentEntries.isNotEmpty) {
        final latest = runtimeSummary.recentEntries.first;
        buffer.writeln(
          '- Latest event: ${latest.kind.jsonValue} ${latest.message}',
        );
      }
      if (runtimeSummary.errorEntries.isNotEmpty) {
        final latestError = runtimeSummary.errorEntries.first;
        buffer.writeln(
          '- Latest error: ${latestError.kind.jsonValue} ${latestError.message}',
        );
      }
    }

    return buffer.toString().trimRight();
  }

  _CockpitAcceptanceNetworkSummary? _summarizeNetworkActivity() {
    final dedupedEntries = <String, CockpitNetworkEntry>{};
    var totalEntryCount = 0;
    var failureCount = 0;
    for (final step in _steps) {
      final network = step.snapshot?.network;
      if (network == null) {
        continue;
      }
      final capturedCount = network.capturedEntryCount > 0
          ? network.capturedEntryCount
          : network.totalEntryCount;
      if (capturedCount > totalEntryCount) {
        totalEntryCount = capturedCount;
      }
      if (network.failureCount > failureCount) {
        failureCount = network.failureCount;
      }
      for (final entry in network.entries) {
        dedupedEntries[entry.requestId] = entry;
      }
    }

    if (dedupedEntries.isEmpty && totalEntryCount == 0 && failureCount == 0) {
      return null;
    }

    final orderedEntries = dedupedEntries.values.toList(growable: true)
      ..sort((left, right) => right.startedAt.compareTo(left.startedAt));
    final failingEntries = orderedEntries
        .where((entry) => entry.isFailure)
        .take(3)
        .toList(growable: false);

    return _CockpitAcceptanceNetworkSummary(
      totalEntryCount:
          totalEntryCount == 0 ? orderedEntries.length : totalEntryCount,
      failureCount: failureCount == 0
          ? orderedEntries.where((entry) => entry.isFailure).length
          : failureCount,
      recentEntries: orderedEntries.take(3).toList(growable: false),
      failingEntries: failingEntries,
    );
  }

  _CockpitAcceptanceRuntimeSummary? _summarizeRuntimeActivity() {
    final dedupedEvents = <String, CockpitRuntimeEvent>{};
    var totalEntryCount = 0;
    var errorCount = 0;
    var warningCount = 0;
    for (final step in _steps) {
      final runtime = step.snapshot?.runtime;
      if (runtime != null) {
        final capturedCount = runtime.capturedEntryCount > 0
            ? runtime.capturedEntryCount
            : runtime.totalEntryCount;
        if (capturedCount > totalEntryCount) {
          totalEntryCount = capturedCount;
        }
        if (runtime.errorCount > errorCount) {
          errorCount = runtime.errorCount;
        }
        if (runtime.warningCount > warningCount) {
          warningCount = runtime.warningCount;
        }
        for (final entry in runtime.entries) {
          dedupedEvents[entry.eventId] = entry;
        }
      }

      if (step.actionType != 'runtime_event') {
        continue;
      }
      final event = _runtimeEventFromStep(step);
      if (event == null) {
        continue;
      }
      dedupedEvents[event.eventId] = event;
    }

    if (dedupedEvents.isEmpty &&
        totalEntryCount == 0 &&
        errorCount == 0 &&
        warningCount == 0) {
      return null;
    }

    final orderedEntries = dedupedEvents.values.toList(growable: true)
      ..sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
    final derivedErrorCount =
        orderedEntries.where((entry) => entry.isError).length;
    final derivedWarningCount =
        orderedEntries.where((entry) => entry.isWarning).length;
    return _CockpitAcceptanceRuntimeSummary(
      totalEntryCount:
          totalEntryCount == 0 ? orderedEntries.length : totalEntryCount,
      errorCount: errorCount == 0 ? derivedErrorCount : errorCount,
      warningCount: warningCount == 0 ? derivedWarningCount : warningCount,
      recentEntries: orderedEntries.take(3).toList(growable: false),
      errorEntries: orderedEntries
          .where((entry) => entry.isError)
          .take(3)
          .toList(growable: false),
    );
  }

  CockpitRuntimeEvent? _runtimeEventFromStep(CockpitStepRecord step) {
    final eventId = step.actionArgs['eventId'] as String?;
    final kind = step.actionArgs['kind'];
    final severity = step.actionArgs['severity'];
    final message = step.actionArgs['message'] as String?;
    if (eventId == null ||
        message == null ||
        kind == null ||
        severity == null) {
      return null;
    }
    final details = step.actionArgs['details'];
    return CockpitRuntimeEvent(
      eventId: eventId,
      kind: CockpitRuntimeEventKind.fromJson(kind),
      severity: CockpitRuntimeEventSeverity.fromJson(severity),
      message: message,
      recordedAt: step.actionArgs['recordedAt'] == null
          ? step.observedAt
          : DateTime.parse(step.actionArgs['recordedAt']! as String).toUtc(),
      routeName: step.actionArgs['routeName'] as String?,
      source: step.actionArgs['source'] as String?,
      details: Map<String, String>.from(
        (details as Map<Object?, Object?>?) ?? const <Object?, Object?>{},
      ),
      stackTracePreview: step.actionArgs['stackTracePreview'] as String?,
      stackTraceTruncated:
          step.actionArgs['stackTraceTruncated'] as bool? ?? false,
    );
  }

  static DateTime _systemNow() => DateTime.now().toUtc();
}

final class _CockpitAcceptanceNetworkSummary {
  const _CockpitAcceptanceNetworkSummary({
    required this.totalEntryCount,
    required this.failureCount,
    required this.recentEntries,
    required this.failingEntries,
  });

  final int totalEntryCount;
  final int failureCount;
  final List<CockpitNetworkEntry> recentEntries;
  final List<CockpitNetworkEntry> failingEntries;
}

final class _CockpitAcceptanceRuntimeSummary {
  const _CockpitAcceptanceRuntimeSummary({
    required this.totalEntryCount,
    required this.errorCount,
    required this.warningCount,
    required this.recentEntries,
    required this.errorEntries,
  });

  final int totalEntryCount;
  final int errorCount;
  final int warningCount;
  final List<CockpitRuntimeEvent> recentEntries;
  final List<CockpitRuntimeEvent> errorEntries;
}
