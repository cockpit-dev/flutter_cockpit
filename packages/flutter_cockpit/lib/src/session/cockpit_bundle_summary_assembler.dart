import 'package:collection/collection.dart';

import '../context/cockpit_context_bundle.dart';
import '../model/cockpit_environment.dart';
import '../model/cockpit_observation.dart';
import '../model/cockpit_run_manifest.dart';
import '../model/cockpit_step_record.dart';
import '../model/cockpit_task_status.dart';
import '../network/cockpit_network_entry.dart';
import '../runtime/cockpit_runtime_event.dart';
import 'cockpit_evidence_index.dart';
import 'cockpit_session.dart';
import 'cockpit_timestamp_provider.dart';

final class CockpitBundleSummaryAssembler {
  CockpitBundleSummaryAssembler({
    CockpitTimestampProvider? now,
  }) : _now = now ?? _systemNow;

  final CockpitTimestampProvider _now;

  CockpitContextBundle assemble({
    required CockpitSession session,
    required CockpitEnvironment environment,
    required List<CockpitStepRecord> steps,
    required CockpitTaskStatus status,
    required List<String> capabilitiesUsed,
    String? failureSummary,
  }) {
    final evidenceIndex = CockpitEvidenceIndex.fromSteps(steps);
    final commandCount = steps.where((step) => step.commandType != null).length;
    final runtimeSummary = _summarizeRuntimeActivity(steps);
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
      sessionId: session.sessionId,
      taskId: session.taskId,
      platform: session.platform,
      status: effectiveStatus,
      startedAt: session.startedAt,
      finishedAt: _now().toUtc(),
      artifactRefs: evidenceIndex.artifactRefs,
      failureSummary: effectiveFailureSummary,
      capabilitiesUsed: capabilitiesUsed,
      commandCount: commandCount,
      screenshotCount: evidenceIndex.screenshotCount,
      failureCount: evidenceIndex.failureCount,
      nativeScreenshotCount: evidenceIndex.nativeScreenshotCount,
      flutterScreenshotCount: evidenceIndex.flutterScreenshotCount,
      deliveryArtifactsReady: evidenceIndex.deliveryArtifactsReady,
      recordingCount: evidenceIndex.recordingCount,
      nativeRecordingCount: evidenceIndex.nativeRecordingCount,
      deliveryVideoReady: evidenceIndex.deliveryVideoReady,
      runtimeEventCount: runtimeEventCount,
      runtimeErrorCount: runtimeErrorCount,
      runtimeWarningCount: runtimeWarningCount,
    );
    final observations = steps
        .map((step) => step.observation)
        .whereType<CockpitObservation>()
        .toList(growable: false);
    final handoff = <String, Object?>{
      'sessionId': session.sessionId,
      'taskId': session.taskId,
      'platform': session.platform,
      'status': effectiveStatus.name,
      'stepCount': steps.length,
      'capabilitiesUsed': capabilitiesUsed,
      'commandCount': commandCount,
      'screenshotCount': evidenceIndex.screenshotCount,
      'failureCount': evidenceIndex.failureCount,
      'nativeScreenshotCount': evidenceIndex.nativeScreenshotCount,
      'flutterScreenshotCount': evidenceIndex.flutterScreenshotCount,
      'deliveryArtifactsReady': evidenceIndex.deliveryArtifactsReady,
      'recordingCount': evidenceIndex.recordingCount,
      'nativeRecordingCount': evidenceIndex.nativeRecordingCount,
      'deliveryVideoReady': evidenceIndex.deliveryVideoReady,
      'runtimeEventCount': runtimeEventCount,
      'runtimeErrorCount': runtimeErrorCount,
      'runtimeWarningCount': runtimeWarningCount,
      if (effectiveFailureSummary != null)
        'failureSummary': effectiveFailureSummary,
    };

    return CockpitContextBundle(
      manifest: manifest,
      environment: environment,
      steps: steps,
      observations: observations,
      acceptanceMarkdown: _buildAcceptanceMarkdown(
        session: session,
        steps: steps,
        evidenceIndex: evidenceIndex,
        status: effectiveStatus,
        failureSummary: effectiveFailureSummary,
        runtimeSummary: runtimeSummary,
      ),
      handoff: handoff,
      delivery: <String, Object?>{
        'summary': effectiveStatus == CockpitTaskStatus.completed
            ? 'Ready for user delivery'
            : 'Delivery blocked by task failure',
        'primaryScreenshotRef': evidenceIndex.primaryScreenshotRef.isEmpty
            ? null
            : evidenceIndex.primaryScreenshotRef,
        'attachmentRefs': evidenceIndex.screenshotRefs,
        'deliveryArtifactsReady': evidenceIndex.deliveryArtifactsReady,
        'primaryRecordingRef': evidenceIndex.primaryRecordingRef.isEmpty
            ? null
            : evidenceIndex.primaryRecordingRef,
        'videoAttachmentRefs': evidenceIndex.recordingRefs,
        'deliveryVideoReady': evidenceIndex.deliveryVideoReady,
      },
    );
  }

  String _buildAcceptanceMarkdown({
    required CockpitSession session,
    required List<CockpitStepRecord> steps,
    required CockpitEvidenceIndex evidenceIndex,
    required CockpitTaskStatus status,
    String? failureSummary,
    _CockpitAcceptanceRuntimeSummary? runtimeSummary,
  }) {
    final lastRecordingFailure = steps
        .where((step) => step.actionType == 'recording_failed')
        .map((step) => step.actionArgs['failureReason'] as String?)
        .whereType<String>()
        .lastOrNull;
    final buffer = StringBuffer()
      ..writeln('# Acceptance')
      ..writeln()
      ..writeln('- Session: ${session.sessionId}')
      ..writeln('- Task: ${session.taskId}')
      ..writeln('- Platform: ${session.platform}')
      ..writeln('- Status: ${status.name}')
      ..writeln('- Steps: ${steps.length}');

    if (failureSummary != null) {
      buffer.writeln('- Failure: $failureSummary');
    }

    buffer.writeln();
    buffer.writeln('## Recording');
    if (evidenceIndex.recordingRefs.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('- Acceptance video: ${evidenceIndex.recordingRefs.first}');
      buffer.writeln('- Recording count: ${evidenceIndex.recordingRefs.length}');
    } else {
      buffer.writeln();
      buffer.writeln('- Recording unavailable');
      if (lastRecordingFailure != null) {
        buffer.writeln('- Recording failure: $lastRecordingFailure');
      }
    }

    final networkSummary = _summarizeNetworkActivity(steps);
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

  _CockpitAcceptanceNetworkSummary? _summarizeNetworkActivity(
    List<CockpitStepRecord> steps,
  ) {
    final dedupedEntries = <String, CockpitNetworkEntry>{};
    var totalEntryCount = 0;
    var failureCount = 0;
    for (final step in steps) {
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

  _CockpitAcceptanceRuntimeSummary? _summarizeRuntimeActivity(
    List<CockpitStepRecord> steps,
  ) {
    final dedupedEvents = <String, CockpitRuntimeEvent>{};
    var totalEntryCount = 0;
    var errorCount = 0;
    var warningCount = 0;
    for (final step in steps) {
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
