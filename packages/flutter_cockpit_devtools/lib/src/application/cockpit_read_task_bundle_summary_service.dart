import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:path/path.dart' as p;

import 'cockpit_application_service_exception.dart';
import 'cockpit_bundle_artifact_paths.dart';
import 'cockpit_task_gate.dart';

final class CockpitBundleNetworkSummary {
  const CockpitBundleNetworkSummary({
    required this.totalEntryCount,
    required this.failureCount,
    required this.truncated,
    this.recentEntries = const <CockpitNetworkEntry>[],
    this.failingEntries = const <CockpitNetworkEntry>[],
  });

  final int totalEntryCount;
  final int failureCount;
  final bool truncated;
  final List<CockpitNetworkEntry> recentEntries;
  final List<CockpitNetworkEntry> failingEntries;

  Map<String, Object?> toJson() => <String, Object?>{
        'totalEntryCount': totalEntryCount,
        'failureCount': failureCount,
        'truncated': truncated,
        'recentEntries': recentEntries
            .map((entry) => entry.toJson())
            .toList(growable: false),
        'failingEntries': failingEntries
            .map((entry) => entry.toJson())
            .toList(growable: false),
      };
}

final class CockpitBundleRuntimeSummary {
  const CockpitBundleRuntimeSummary({
    required this.totalEntryCount,
    required this.errorCount,
    required this.warningCount,
    required this.truncated,
    this.recentEntries = const <CockpitRuntimeEvent>[],
    this.errorEntries = const <CockpitRuntimeEvent>[],
  });

  final int totalEntryCount;
  final int errorCount;
  final int warningCount;
  final bool truncated;
  final List<CockpitRuntimeEvent> recentEntries;
  final List<CockpitRuntimeEvent> errorEntries;

  Map<String, Object?> toJson() => <String, Object?>{
        'totalEntryCount': totalEntryCount,
        'errorCount': errorCount,
        'warningCount': warningCount,
        'truncated': truncated,
        'recentEntries': recentEntries
            .map((entry) => entry.toJson())
            .toList(growable: false),
        'errorEntries':
            errorEntries.map((entry) => entry.toJson()).toList(growable: false),
      };
}

final class CockpitBundleRebuildSummary {
  const CockpitBundleRebuildSummary({
    required this.totalRebuildCount,
    required this.uniqueElementCount,
    required this.truncated,
    this.entries = const <CockpitRebuildEntry>[],
  });

  final int totalRebuildCount;
  final int uniqueElementCount;
  final bool truncated;
  final List<CockpitRebuildEntry> entries;

  Map<String, Object?> toJson() => <String, Object?>{
        'totalRebuildCount': totalRebuildCount,
        'uniqueElementCount': uniqueElementCount,
        'truncated': truncated,
        'entries':
            entries.map((entry) => entry.toJson()).toList(growable: false),
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'total_rebuild_count': totalRebuildCount,
        'unique_element_count': uniqueElementCount,
        'truncated': truncated,
        'entries': entries
            .map(
              (entry) => <String, Object?>{
                'signature': entry.signature,
                'route_name': entry.routeName,
                'type_name': entry.typeName,
                'rebuild_count': entry.rebuildCount,
                'built_once_count': entry.builtOnceCount,
                'key_value': entry.keyValue,
                'semantic_id': entry.semanticId,
                'text_preview': entry.textPreview,
              },
            )
            .toList(growable: false),
      };
}

final class CockpitBundleAcceptanceEvidence {
  CockpitBundleAcceptanceEvidence({
    required this.routeName,
    required this.diagnosticLevel,
    required this.diagnosticsArtifactPath,
    required List<String> visibleTextPreviews,
    required List<String> visibleSemanticIds,
    required List<String> interactiveLabels,
    required List<String> accessibilityLabels,
    required this.visibleTargetCount,
    required this.accessibilityEntryCount,
    required this.hasAccessibilitySummary,
    required this.networkEntryCount,
    required this.networkFailureCount,
    required List<CockpitBundleAcceptanceNetworkSignal> networkFailureSignals,
    required this.runtimeEntryCount,
    required this.runtimeErrorCount,
    required this.runtimeWarningCount,
    required List<CockpitBundleAcceptanceRuntimeSignal> runtimeErrorSignals,
    required this.rebuildTotalCount,
    required this.rebuildUniqueElementCount,
    required List<CockpitBundleAcceptanceRebuildHotspot> rebuildHotspots,
  })  : visibleTextPreviews = List.unmodifiable(visibleTextPreviews),
        visibleSemanticIds = List.unmodifiable(visibleSemanticIds),
        interactiveLabels = List.unmodifiable(interactiveLabels),
        accessibilityLabels = List.unmodifiable(accessibilityLabels),
        networkFailureSignals = List.unmodifiable(networkFailureSignals),
        runtimeErrorSignals = List.unmodifiable(runtimeErrorSignals),
        rebuildHotspots = List.unmodifiable(rebuildHotspots);

  final String? routeName;
  final String? diagnosticLevel;
  final String? diagnosticsArtifactPath;
  final List<String> visibleTextPreviews;
  final List<String> visibleSemanticIds;
  final List<String> interactiveLabels;
  final List<String> accessibilityLabels;
  final int visibleTargetCount;
  final int accessibilityEntryCount;
  final bool hasAccessibilitySummary;
  final int networkEntryCount;
  final int networkFailureCount;
  final List<CockpitBundleAcceptanceNetworkSignal> networkFailureSignals;
  final int runtimeEntryCount;
  final int runtimeErrorCount;
  final int runtimeWarningCount;
  final List<CockpitBundleAcceptanceRuntimeSignal> runtimeErrorSignals;
  final int rebuildTotalCount;
  final int rebuildUniqueElementCount;
  final List<CockpitBundleAcceptanceRebuildHotspot> rebuildHotspots;

  bool get hasSemanticSignals =>
      visibleTextPreviews.isNotEmpty ||
      visibleSemanticIds.isNotEmpty ||
      interactiveLabels.isNotEmpty ||
      accessibilityLabels.isNotEmpty;

  bool get hasComparableSignals =>
      (routeName != null && routeName!.isNotEmpty) ||
      hasSemanticSignals ||
      visibleTargetCount > 0 ||
      accessibilityEntryCount > 0 ||
      networkEntryCount > 0 ||
      runtimeEntryCount > 0 ||
      rebuildTotalCount > 0;

  Map<String, Object?> toJson() => <String, Object?>{
        'routeName': routeName,
        'diagnosticLevel': diagnosticLevel,
        'diagnosticsArtifactPath': diagnosticsArtifactPath,
        'visibleTextPreviews': visibleTextPreviews,
        'visibleSemanticIds': visibleSemanticIds,
        'interactiveLabels': interactiveLabels,
        'accessibilityLabels': accessibilityLabels,
        'visibleTargetCount': visibleTargetCount,
        'accessibilityEntryCount': accessibilityEntryCount,
        'hasAccessibilitySummary': hasAccessibilitySummary,
        'networkEntryCount': networkEntryCount,
        'networkFailureCount': networkFailureCount,
        'networkFailureSignals': networkFailureSignals
            .map((signal) => signal.toJson())
            .toList(growable: false),
        'runtimeEntryCount': runtimeEntryCount,
        'runtimeErrorCount': runtimeErrorCount,
        'runtimeWarningCount': runtimeWarningCount,
        'runtimeErrorSignals': runtimeErrorSignals
            .map((signal) => signal.toJson())
            .toList(growable: false),
        'rebuildTotalCount': rebuildTotalCount,
        'rebuildUniqueElementCount': rebuildUniqueElementCount,
        'rebuildHotspots': rebuildHotspots
            .map((hotspot) => hotspot.toJson())
            .toList(growable: false),
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'route_name': routeName,
        'diagnostic_level': diagnosticLevel,
        'diagnostics_artifact_path': diagnosticsArtifactPath,
        'visible_text_previews': visibleTextPreviews,
        'visible_semantic_ids': visibleSemanticIds,
        'interactive_labels': interactiveLabels,
        'accessibility_labels': accessibilityLabels,
        'visible_target_count': visibleTargetCount,
        'accessibility_entry_count': accessibilityEntryCount,
        'has_accessibility_summary': hasAccessibilitySummary,
        'network_entry_count': networkEntryCount,
        'network_failure_count': networkFailureCount,
        'network_failure_signals': networkFailureSignals
            .map((signal) => signal.toMcpJson())
            .toList(growable: false),
        'runtime_entry_count': runtimeEntryCount,
        'runtime_error_count': runtimeErrorCount,
        'runtime_warning_count': runtimeWarningCount,
        'runtime_error_signals': runtimeErrorSignals
            .map((signal) => signal.toMcpJson())
            .toList(growable: false),
        'rebuild_total_count': rebuildTotalCount,
        'rebuild_unique_element_count': rebuildUniqueElementCount,
        'rebuild_hotspots': rebuildHotspots
            .map((hotspot) => hotspot.toMcpJson())
            .toList(growable: false),
      };
}

final class CockpitBundleAcceptanceDelta {
  CockpitBundleAcceptanceDelta({
    required this.baselineRouteName,
    required this.acceptanceRouteName,
    required this.routeChanged,
    required List<String> addedVisibleTextPreviews,
    required List<String> removedVisibleTextPreviews,
    required List<String> addedSemanticIds,
    required List<String> removedSemanticIds,
    required List<String> addedInteractiveLabels,
    required List<String> removedInteractiveLabels,
    required List<String> addedAccessibilityLabels,
    required List<String> removedAccessibilityLabels,
    required this.networkFailureDeltaCount,
    required List<CockpitBundleAcceptanceNetworkSignal>
        newNetworkFailureSignals,
    required this.runtimeErrorDeltaCount,
    required List<CockpitBundleAcceptanceRuntimeSignal> newRuntimeErrorSignals,
    required this.rebuildTotalDeltaCount,
    required this.rebuildUniqueElementDeltaCount,
    required List<CockpitBundleAcceptanceRebuildHotspot> newRebuildHotspots,
  })  : addedVisibleTextPreviews = List.unmodifiable(addedVisibleTextPreviews),
        removedVisibleTextPreviews = List.unmodifiable(
          removedVisibleTextPreviews,
        ),
        addedSemanticIds = List.unmodifiable(addedSemanticIds),
        removedSemanticIds = List.unmodifiable(removedSemanticIds),
        addedInteractiveLabels = List.unmodifiable(addedInteractiveLabels),
        removedInteractiveLabels = List.unmodifiable(removedInteractiveLabels),
        addedAccessibilityLabels = List.unmodifiable(addedAccessibilityLabels),
        removedAccessibilityLabels = List.unmodifiable(
          removedAccessibilityLabels,
        ),
        newNetworkFailureSignals = List.unmodifiable(newNetworkFailureSignals),
        newRuntimeErrorSignals = List.unmodifiable(newRuntimeErrorSignals),
        newRebuildHotspots = List.unmodifiable(newRebuildHotspots);

  final String? baselineRouteName;
  final String? acceptanceRouteName;
  final bool routeChanged;
  final List<String> addedVisibleTextPreviews;
  final List<String> removedVisibleTextPreviews;
  final List<String> addedSemanticIds;
  final List<String> removedSemanticIds;
  final List<String> addedInteractiveLabels;
  final List<String> removedInteractiveLabels;
  final List<String> addedAccessibilityLabels;
  final List<String> removedAccessibilityLabels;
  final int networkFailureDeltaCount;
  final List<CockpitBundleAcceptanceNetworkSignal> newNetworkFailureSignals;
  final int runtimeErrorDeltaCount;
  final List<CockpitBundleAcceptanceRuntimeSignal> newRuntimeErrorSignals;
  final int rebuildTotalDeltaCount;
  final int rebuildUniqueElementDeltaCount;
  final List<CockpitBundleAcceptanceRebuildHotspot> newRebuildHotspots;

  int get semanticSignalDeltaCount =>
      addedVisibleTextPreviews.length +
      removedVisibleTextPreviews.length +
      addedSemanticIds.length +
      removedSemanticIds.length +
      addedInteractiveLabels.length +
      removedInteractiveLabels.length +
      addedAccessibilityLabels.length +
      removedAccessibilityLabels.length;

  Map<String, Object?> toJson() => <String, Object?>{
        'baselineRouteName': baselineRouteName,
        'acceptanceRouteName': acceptanceRouteName,
        'routeChanged': routeChanged,
        'addedVisibleTextPreviews': addedVisibleTextPreviews,
        'removedVisibleTextPreviews': removedVisibleTextPreviews,
        'addedSemanticIds': addedSemanticIds,
        'removedSemanticIds': removedSemanticIds,
        'addedInteractiveLabels': addedInteractiveLabels,
        'removedInteractiveLabels': removedInteractiveLabels,
        'addedAccessibilityLabels': addedAccessibilityLabels,
        'removedAccessibilityLabels': removedAccessibilityLabels,
        'networkFailureDeltaCount': networkFailureDeltaCount,
        'newNetworkFailureSignals': newNetworkFailureSignals
            .map((signal) => signal.toJson())
            .toList(growable: false),
        'runtimeErrorDeltaCount': runtimeErrorDeltaCount,
        'newRuntimeErrorSignals': newRuntimeErrorSignals
            .map((signal) => signal.toJson())
            .toList(growable: false),
        'rebuildTotalDeltaCount': rebuildTotalDeltaCount,
        'rebuildUniqueElementDeltaCount': rebuildUniqueElementDeltaCount,
        'newRebuildHotspots': newRebuildHotspots
            .map((hotspot) => hotspot.toJson())
            .toList(growable: false),
        'semanticSignalDeltaCount': semanticSignalDeltaCount,
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'baseline_route_name': baselineRouteName,
        'acceptance_route_name': acceptanceRouteName,
        'route_changed': routeChanged,
        'added_visible_text_previews': addedVisibleTextPreviews,
        'removed_visible_text_previews': removedVisibleTextPreviews,
        'added_semantic_ids': addedSemanticIds,
        'removed_semantic_ids': removedSemanticIds,
        'added_interactive_labels': addedInteractiveLabels,
        'removed_interactive_labels': removedInteractiveLabels,
        'added_accessibility_labels': addedAccessibilityLabels,
        'removed_accessibility_labels': removedAccessibilityLabels,
        'network_failure_delta_count': networkFailureDeltaCount,
        'new_network_failure_signals': newNetworkFailureSignals
            .map((signal) => signal.toMcpJson())
            .toList(growable: false),
        'runtime_error_delta_count': runtimeErrorDeltaCount,
        'new_runtime_error_signals': newRuntimeErrorSignals
            .map((signal) => signal.toMcpJson())
            .toList(growable: false),
        'rebuild_total_delta_count': rebuildTotalDeltaCount,
        'rebuild_unique_element_delta_count': rebuildUniqueElementDeltaCount,
        'new_rebuild_hotspots': newRebuildHotspots
            .map((hotspot) => hotspot.toMcpJson())
            .toList(growable: false),
        'semantic_signal_delta_count': semanticSignalDeltaCount,
      };
}

final class CockpitBundleAcceptanceNetworkSignal {
  const CockpitBundleAcceptanceNetworkSignal({
    required this.requestId,
    required this.method,
    required this.uri,
    required this.statusCode,
    required this.error,
    required this.durationMs,
  });

  final String requestId;
  final String method;
  final String uri;
  final int? statusCode;
  final String? error;
  final int durationMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'requestId': requestId,
        'method': method,
        'uri': uri,
        'statusCode': statusCode,
        'error': error,
        'durationMs': durationMs,
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'request_id': requestId,
        'method': method,
        'uri': uri,
        'status_code': statusCode,
        'error': error,
        'duration_ms': durationMs,
      };
}

final class CockpitBundleAcceptanceRuntimeSignal {
  const CockpitBundleAcceptanceRuntimeSignal({
    required this.eventId,
    required this.kind,
    required this.severity,
    required this.message,
  });

  final String eventId;
  final String kind;
  final String severity;
  final String message;

  Map<String, Object?> toJson() => <String, Object?>{
        'eventId': eventId,
        'kind': kind,
        'severity': severity,
        'message': message,
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'event_id': eventId,
        'kind': kind,
        'severity': severity,
        'message': message,
      };
}

final class CockpitBundleAcceptanceRebuildHotspot {
  const CockpitBundleAcceptanceRebuildHotspot({
    required this.signature,
    required this.routeName,
    required this.typeName,
    required this.rebuildCount,
    required this.keyValue,
    required this.semanticId,
    required this.textPreview,
  });

  final String signature;
  final String routeName;
  final String typeName;
  final int rebuildCount;
  final String? keyValue;
  final String? semanticId;
  final String? textPreview;

  Map<String, Object?> toJson() => <String, Object?>{
        'signature': signature,
        'routeName': routeName,
        'typeName': typeName,
        'rebuildCount': rebuildCount,
        'keyValue': keyValue,
        'semanticId': semanticId,
        'textPreview': textPreview,
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'signature': signature,
        'route_name': routeName,
        'type_name': typeName,
        'rebuild_count': rebuildCount,
        'key_value': keyValue,
        'semantic_id': semanticId,
        'text_preview': textPreview,
      };
}

final class CockpitReadTaskBundleSummaryRequest {
  const CockpitReadTaskBundleSummaryRequest({required this.bundleDir});

  final String bundleDir;
}

final class CockpitBundleGateSummary {
  const CockpitBundleGateSummary({
    this.gates = const <CockpitTaskGate, bool>{},
    this.failureCodes = const <CockpitTaskGate, List<String>>{},
  });

  final Map<CockpitTaskGate, bool> gates;
  final Map<CockpitTaskGate, List<String>> failureCodes;

  bool isSatisfied(CockpitTaskGate gate) => gates[gate] ?? false;

  List<String> failureCodesFor(CockpitTaskGate gate) =>
      failureCodes[gate] ?? const <String>[];

  Map<String, Object?> toJson() => <String, Object?>{
        'gates': <String, Object?>{
          for (final entry in gates.entries) entry.key.name: entry.value,
        },
        'failureCodes': <String, Object?>{
          for (final entry in failureCodes.entries) entry.key.name: entry.value,
        },
      };

  Map<String, Object?> toMcpJson() => toJson();
}

final class CockpitReadTaskBundleSummaryResult {
  const CockpitReadTaskBundleSummaryResult({
    required this.bundleDir,
    required this.manifest,
    required this.handoff,
    required this.delivery,
    required this.acceptanceMarkdown,
    required this.artifactPaths,
    required this.evidenceSummary,
    this.baselineEvidence,
    this.acceptanceEvidence,
    this.acceptanceDelta,
    this.diagnosticsArtifactPaths = const <String>[],
    this.networkSummary,
    this.runtimeSummary,
    this.rebuildSummary,
    this.gateSummary = const CockpitBundleGateSummary(),
  });

  final String bundleDir;
  final CockpitRunManifest manifest;
  final Map<String, Object?> handoff;
  final Map<String, Object?> delivery;
  final String acceptanceMarkdown;
  final CockpitBundleArtifactPaths artifactPaths;
  final Map<String, Object?> evidenceSummary;
  final CockpitBundleAcceptanceEvidence? baselineEvidence;
  final CockpitBundleAcceptanceEvidence? acceptanceEvidence;
  final CockpitBundleAcceptanceDelta? acceptanceDelta;
  final List<String> diagnosticsArtifactPaths;
  final CockpitBundleNetworkSummary? networkSummary;
  final CockpitBundleRuntimeSummary? runtimeSummary;
  final CockpitBundleRebuildSummary? rebuildSummary;
  final CockpitBundleGateSummary gateSummary;

  Map<String, Object?> toJson() => <String, Object?>{
        'bundleDir': bundleDir,
        'manifest': manifest.toJson(),
        'handoff': handoff,
        'delivery': delivery,
        'acceptanceMarkdown': acceptanceMarkdown,
        'artifactPaths': artifactPaths.toJson(),
        'evidence': evidence.toJson(),
        'evidenceSummary': evidenceSummary,
        'gateSummary': gateSummary.toJson(),
        if (baselineEvidence != null)
          'baselineEvidence': baselineEvidence!.toJson(),
        if (acceptanceEvidence != null)
          'acceptanceEvidence': acceptanceEvidence!.toJson(),
        if (acceptanceDelta != null)
          'acceptanceDelta': acceptanceDelta!.toJson(),
        'diagnosticsArtifactPaths': diagnosticsArtifactPaths,
        if (networkSummary != null) 'networkSummary': networkSummary!.toJson(),
        if (runtimeSummary != null) 'runtimeSummary': runtimeSummary!.toJson(),
        if (rebuildSummary != null) 'rebuildSummary': rebuildSummary!.toJson(),
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'bundle_dir': bundleDir,
        'manifest': manifest.toJson(),
        'handoff': handoff,
        'delivery': delivery,
        'acceptance_markdown': acceptanceMarkdown,
        'artifact_paths': artifactPaths.toJson(),
        'evidence': evidence.toMcpJson(),
        'evidence_summary': evidenceSummary,
        'gate_summary': gateSummary.toMcpJson(),
        if (baselineEvidence != null)
          'baseline_evidence': baselineEvidence!.toMcpJson(),
        if (acceptanceEvidence != null)
          'acceptance_evidence': acceptanceEvidence!.toMcpJson(),
        if (acceptanceDelta != null)
          'acceptance_delta': acceptanceDelta!.toMcpJson(),
        'diagnostics_artifact_paths': diagnosticsArtifactPaths,
        if (networkSummary != null) 'network_summary': networkSummary!.toJson(),
        if (runtimeSummary != null) 'runtime_summary': runtimeSummary!.toJson(),
        if (rebuildSummary != null)
          'rebuild_summary': rebuildSummary!.toMcpJson(),
      };

  CockpitBundleEvidenceView get evidence => CockpitBundleEvidenceView(
        primaryScreenshotPath: artifactPaths.primaryScreenshotPath,
        attachmentPaths: artifactPaths.attachmentPaths,
        primaryRecordingPath: artifactPaths.primaryRecordingPath,
        videoAttachmentPaths: artifactPaths.videoAttachmentPaths,
        keyframePaths: artifactPaths.keyframePaths,
        diagnosticsArtifactPaths: diagnosticsArtifactPaths,
        deliveryArtifactsReady: manifest.deliveryArtifactsReady,
        deliveryVideoReady: manifest.deliveryVideoReady,
        deliveryKeyframesReady: delivery['deliveryKeyframesReady'] == true,
        keyframeCoverage: _readEvidenceMap(delivery['keyframeCoverage']),
        keyframes: _readEvidenceKeyframes(bundleDir, delivery['keyframes']),
      );

  static Map<String, Object?>? _readEvidenceMap(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }
    return Map<String, Object?>.from(value);
  }

  static List<CockpitBundleEvidenceKeyframe> _readEvidenceKeyframes(
    String bundleDir,
    Object? value,
  ) {
    final keyframes = (value as List<Object?>? ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) => Map<String, Object?>.from(item))
        .map(
          (item) => CockpitBundleEvidenceKeyframe.fromDeliveryEntry(
            bundleDir: bundleDir,
            json: item,
          ),
        )
        .toList(growable: false);
    return List<CockpitBundleEvidenceKeyframe>.unmodifiable(keyframes);
  }
}

final class CockpitBundleEvidenceView {
  CockpitBundleEvidenceView({
    required this.primaryScreenshotPath,
    required List<String> attachmentPaths,
    required this.primaryRecordingPath,
    required List<String> videoAttachmentPaths,
    required List<String> keyframePaths,
    required List<String> diagnosticsArtifactPaths,
    required this.deliveryArtifactsReady,
    required this.deliveryVideoReady,
    required this.deliveryKeyframesReady,
    required this.keyframeCoverage,
    required List<CockpitBundleEvidenceKeyframe> keyframes,
  })  : attachmentPaths = List.unmodifiable(attachmentPaths),
        videoAttachmentPaths = List.unmodifiable(videoAttachmentPaths),
        keyframePaths = List.unmodifiable(keyframePaths),
        diagnosticsArtifactPaths = List.unmodifiable(diagnosticsArtifactPaths),
        keyframes = List.unmodifiable(keyframes);

  final String? primaryScreenshotPath;
  final List<String> attachmentPaths;
  final String? primaryRecordingPath;
  final List<String> videoAttachmentPaths;
  final List<String> keyframePaths;
  final List<String> diagnosticsArtifactPaths;
  final bool deliveryArtifactsReady;
  final bool deliveryVideoReady;
  final bool deliveryKeyframesReady;
  final Map<String, Object?>? keyframeCoverage;
  final List<CockpitBundleEvidenceKeyframe> keyframes;

  Map<String, Object?> toJson() => <String, Object?>{
        'primaryScreenshotPath': primaryScreenshotPath,
        'attachmentPaths': attachmentPaths,
        'primaryRecordingPath': primaryRecordingPath,
        'videoAttachmentPaths': videoAttachmentPaths,
        'keyframePaths': keyframePaths,
        'diagnosticsArtifactPaths': diagnosticsArtifactPaths,
        'deliveryArtifactsReady': deliveryArtifactsReady,
        'deliveryVideoReady': deliveryVideoReady,
        'deliveryKeyframesReady': deliveryKeyframesReady,
        'keyframeCount': keyframePaths.length,
        if (keyframeCoverage != null) 'keyframeCoverage': keyframeCoverage,
        'keyframes': keyframes
            .map((keyframe) => keyframe.toJson())
            .toList(growable: false),
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'primary_screenshot_path': primaryScreenshotPath,
        'attachment_paths': attachmentPaths,
        'primary_recording_path': primaryRecordingPath,
        'video_attachment_paths': videoAttachmentPaths,
        'keyframe_paths': keyframePaths,
        'diagnostics_artifact_paths': diagnosticsArtifactPaths,
        'delivery_artifacts_ready': deliveryArtifactsReady,
        'delivery_video_ready': deliveryVideoReady,
        'delivery_keyframes_ready': deliveryKeyframesReady,
        'keyframe_count': keyframePaths.length,
        if (keyframeCoverage != null) 'keyframe_coverage': keyframeCoverage,
        'keyframes': keyframes
            .map((keyframe) => keyframe.toMcpJson())
            .toList(growable: false),
      };
}

final class CockpitBundleEvidenceKeyframe {
  const CockpitBundleEvidenceKeyframe({
    required this.ref,
    required this.path,
    required this.label,
    required this.offsetMs,
    this.linkedScreenshotRef,
    this.linkedScreenshotPath,
  });

  factory CockpitBundleEvidenceKeyframe.fromDeliveryEntry({
    required String bundleDir,
    required Map<String, Object?> json,
  }) {
    final ref = json['ref'] as String? ?? '';
    final linkedScreenshotRef = json['linkedScreenshotRef'] as String?;
    return CockpitBundleEvidenceKeyframe(
      ref: ref,
      path: ref.isEmpty ? '' : p.join(bundleDir, ref),
      label: json['label'] as String? ?? '',
      offsetMs: json['offsetMs'] as int? ?? 0,
      linkedScreenshotRef: linkedScreenshotRef,
      linkedScreenshotPath: linkedScreenshotRef == null
          ? null
          : p.join(bundleDir, linkedScreenshotRef),
    );
  }

  final String ref;
  final String path;
  final String label;
  final int offsetMs;
  final String? linkedScreenshotRef;
  final String? linkedScreenshotPath;

  Map<String, Object?> toJson() => <String, Object?>{
        'ref': ref,
        'path': path,
        'label': label,
        'offsetMs': offsetMs,
        'linkedScreenshotRef': linkedScreenshotRef,
        'linkedScreenshotPath': linkedScreenshotPath,
      };

  Map<String, Object?> toMcpJson() => <String, Object?>{
        'ref': ref,
        'path': path,
        'label': label,
        'offset_ms': offsetMs,
        'linked_screenshot_ref': linkedScreenshotRef,
        'linked_screenshot_path': linkedScreenshotPath,
      };
}

final class CockpitReadTaskBundleSummaryService {
  const CockpitReadTaskBundleSummaryService();

  Future<CockpitReadTaskBundleSummaryResult> read(
    CockpitReadTaskBundleSummaryRequest request,
  ) async {
    final bundleDir = p.normalize(request.bundleDir);
    final manifest = CockpitRunManifest.fromJson(
      await _readJsonObject(p.join(bundleDir, 'manifest.json')),
    );
    final handoff = await _readJsonObject(p.join(bundleDir, 'handoff.json'));
    final delivery = await _readJsonObject(p.join(bundleDir, 'delivery.json'));
    final acceptanceMarkdown = await _readTextFile(
      p.join(bundleDir, 'acceptance.md'),
    );
    final artifactPaths = CockpitBundleArtifactPaths.fromDelivery(
      bundleDir: bundleDir,
      delivery: delivery,
    );
    final diagnosticsArtifactPaths = await _readDiagnosticsArtifactPaths(
      bundleDir,
    );
    final baselineEvidence = await _readBaselineEvidence(bundleDir);
    final acceptanceEvidence = await _readAcceptanceEvidence(bundleDir);
    final acceptanceDelta =
        baselineEvidence == null || acceptanceEvidence == null
            ? null
            : _buildAcceptanceDelta(
                baselineEvidence: baselineEvidence,
                acceptanceEvidence: acceptanceEvidence,
              );
    final networkSummary = await _readNetworkSummary(bundleDir);
    final runtimeSummary = await _readRuntimeSummary(bundleDir);
    final rebuildSummary = await _readRebuildSummary(bundleDir);
    final gateSummary = _buildBundleGateSummary(
      manifest: manifest,
      handoff: handoff,
      delivery: delivery,
      baselineEvidence: baselineEvidence,
      acceptanceEvidence: acceptanceEvidence,
      acceptanceDelta: acceptanceDelta,
    );

    return CockpitReadTaskBundleSummaryResult(
      bundleDir: bundleDir,
      manifest: manifest,
      handoff: handoff,
      delivery: delivery,
      acceptanceMarkdown: acceptanceMarkdown,
      artifactPaths: artifactPaths,
      evidenceSummary: <String, Object?>{
        'status': manifest.status.name,
        'commandCount': manifest.commandCount,
        'screenshotCount': manifest.screenshotCount,
        'recordingCount': manifest.recordingCount,
        'failureCount': manifest.failureCount,
        'keyframeCount': artifactPaths.keyframePaths.length,
        'deliveryKeyframesReady': delivery['deliveryKeyframesReady'] == true,
        'diagnosticsArtifactCount': diagnosticsArtifactPaths.length,
        'networkEntryCount': networkSummary?.totalEntryCount ?? 0,
        'networkFailureCount': networkSummary?.failureCount ?? 0,
        'runtimeEventCount': runtimeSummary?.totalEntryCount ?? 0,
        'runtimeErrorCount': runtimeSummary?.errorCount ?? 0,
        'runtimeWarningCount': runtimeSummary?.warningCount ?? 0,
        'rebuildTotalCount': rebuildSummary?.totalRebuildCount ?? 0,
        'rebuildUniqueElementCount': rebuildSummary?.uniqueElementCount ?? 0,
        'baselineSemanticSignalCount': baselineEvidence == null
            ? 0
            : baselineEvidence.visibleTextPreviews.length +
                baselineEvidence.visibleSemanticIds.length +
                baselineEvidence.interactiveLabels.length +
                baselineEvidence.accessibilityLabels.length,
        'acceptanceSemanticSignalCount': acceptanceEvidence == null
            ? 0
            : acceptanceEvidence.visibleTextPreviews.length +
                acceptanceEvidence.visibleSemanticIds.length +
                acceptanceEvidence.interactiveLabels.length +
                acceptanceEvidence.accessibilityLabels.length,
        'acceptanceAccessibilityEntryCount':
            acceptanceEvidence?.accessibilityEntryCount ?? 0,
        'acceptanceInteractiveLabelCount':
            acceptanceEvidence?.interactiveLabels.length ?? 0,
        'acceptanceNetworkFailureCount':
            acceptanceEvidence?.networkFailureCount ?? 0,
        'acceptanceRuntimeErrorCount':
            acceptanceEvidence?.runtimeErrorCount ?? 0,
        'acceptanceRebuildHotspotCount':
            acceptanceEvidence?.rebuildHotspots.length ?? 0,
        'acceptanceRouteChanged': acceptanceDelta?.routeChanged ?? false,
        'acceptanceSemanticSignalDeltaCount':
            acceptanceDelta?.semanticSignalDeltaCount ?? 0,
        'acceptanceNewNetworkFailureCount':
            acceptanceDelta?.newNetworkFailureSignals.length ?? 0,
        'acceptanceNewRuntimeErrorCount':
            acceptanceDelta?.newRuntimeErrorSignals.length ?? 0,
        'acceptanceComparisonReady': _isAcceptanceComparisonReady(
          baselineEvidence: baselineEvidence,
          acceptanceEvidence: acceptanceEvidence,
          acceptanceDelta: acceptanceDelta,
        ),
        'screenshotReady': gateSummary.isSatisfied(
          CockpitTaskGate.screenshotReady,
        ),
        'recordingReadyOrExplained': gateSummary.isSatisfied(
          CockpitTaskGate.recordingReadyOrExplained,
        ),
        'acceptanceEvidenceReadable': gateSummary.isSatisfied(
          CockpitTaskGate.acceptanceEvidenceReadable,
        ),
        'deliveryValidated': gateSummary.isSatisfied(
          CockpitTaskGate.deliveryValidated,
        ),
        'finalAssertionPassed': gateSummary.isSatisfied(
          CockpitTaskGate.finalAssertionPassed,
        ),
        'screenshotGateFailureCodes': gateSummary.failureCodesFor(
          CockpitTaskGate.screenshotReady,
        ),
        'recordingGateFailureCodes': gateSummary.failureCodesFor(
          CockpitTaskGate.recordingReadyOrExplained,
        ),
        'acceptanceEvidenceFailureCodes': gateSummary.failureCodesFor(
          CockpitTaskGate.acceptanceEvidenceReadable,
        ),
        'finalAssertionFailureCodes': gateSummary.failureCodesFor(
          CockpitTaskGate.finalAssertionPassed,
        ),
        'gateSummary': gateSummary.toJson(),
      },
      baselineEvidence: baselineEvidence,
      acceptanceEvidence: acceptanceEvidence,
      acceptanceDelta: acceptanceDelta,
      diagnosticsArtifactPaths: diagnosticsArtifactPaths,
      networkSummary: networkSummary,
      runtimeSummary: runtimeSummary,
      rebuildSummary: rebuildSummary,
      gateSummary: gateSummary,
    );
  }

  Future<Map<String, Object?>> _readJsonObject(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'bundleFileMissing',
        message: 'Bundle file does not exist.',
        details: <String, Object?>{'path': path},
      );
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidBundleJson',
        message: 'Bundle JSON must decode to an object.',
        details: <String, Object?>{'path': path},
      );
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<String> _readTextFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw CockpitApplicationServiceException(
        code: 'bundleFileMissing',
        message: 'Bundle file does not exist.',
        details: <String, Object?>{'path': path},
      );
    }
    return file.readAsString();
  }

  Future<List<String>> _readDiagnosticsArtifactPaths(String bundleDir) async {
    final diagnosticsPaths = <String>{};
    final stepsFile = File(p.join(bundleDir, 'steps.json'));
    if (stepsFile.existsSync()) {
      final decoded = jsonDecode(await stepsFile.readAsString());
      if (decoded is! List<Object?>) {
        throw CockpitApplicationServiceException(
          code: 'invalidBundleJson',
          message: 'steps.json must decode to a list.',
          details: <String, Object?>{'path': stepsFile.path},
        );
      }
      for (final item in decoded.cast<Object?>()) {
        if (item is! Map<Object?, Object?>) {
          continue;
        }
        final step = CockpitStepRecord.fromJson(
          Map<String, Object?>.from(item),
        );
        final diagnosticsArtifactRef = step.snapshot?.diagnosticsArtifactRef;
        if (diagnosticsArtifactRef != null) {
          diagnosticsPaths.add(
            p.join(bundleDir, diagnosticsArtifactRef.relativePath),
          );
        }
        for (final artifact in step.artifactRefs) {
          if (artifact.role == 'diagnostics') {
            diagnosticsPaths.add(p.join(bundleDir, artifact.relativePath));
          }
        }
      }
    }

    final observationsFile = File(p.join(bundleDir, 'observations.json'));
    if (observationsFile.existsSync()) {
      final decoded = jsonDecode(await observationsFile.readAsString());
      if (decoded is! List<Object?>) {
        throw CockpitApplicationServiceException(
          code: 'invalidBundleJson',
          message: 'observations.json must decode to a list.',
          details: <String, Object?>{'path': observationsFile.path},
        );
      }
      for (final item in decoded.cast<Object?>()) {
        if (item is! Map<Object?, Object?>) {
          continue;
        }
        final observation = CockpitObservation.fromJson(
          Map<String, Object?>.from(item),
        );
        final diagnosticsArtifactRef = observation.diagnosticsArtifactRef;
        if (diagnosticsArtifactRef != null) {
          diagnosticsPaths.add(
            p.join(bundleDir, diagnosticsArtifactRef.relativePath),
          );
        }
      }
    }

    return diagnosticsPaths.toList(growable: false);
  }

  Future<CockpitBundleNetworkSummary?> _readNetworkSummary(
    String bundleDir,
  ) async {
    final snapshots = await _readSnapshotsForNetworkSummary(bundleDir);
    if (snapshots.isEmpty) {
      return null;
    }

    final dedupedEntries = <String, CockpitNetworkEntry>{};
    var totalEntryCount = 0;
    var failureCount = 0;
    var truncated = false;
    for (final snapshot in snapshots) {
      final network = snapshot.network;
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
      truncated = truncated || network.truncated;
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

    return CockpitBundleNetworkSummary(
      totalEntryCount:
          totalEntryCount == 0 ? orderedEntries.length : totalEntryCount,
      failureCount: failureCount == 0
          ? orderedEntries.where((entry) => entry.isFailure).length
          : failureCount,
      truncated: truncated ||
          (totalEntryCount > 0 && orderedEntries.length < totalEntryCount),
      recentEntries: orderedEntries.take(5).toList(growable: false),
      failingEntries: failingEntries,
    );
  }

  Future<CockpitBundleRuntimeSummary?> _readRuntimeSummary(
    String bundleDir,
  ) async {
    final snapshots = await _readSnapshotsForNetworkSummary(bundleDir);
    final dedupedEvents = <String, CockpitRuntimeEvent>{};
    var totalEntryCount = 0;
    var errorCount = 0;
    var warningCount = 0;
    var truncated = false;

    final stepsFile = File(p.join(bundleDir, 'steps.json'));
    if (stepsFile.existsSync()) {
      final decoded = jsonDecode(await stepsFile.readAsString());
      if (decoded is! List<Object?>) {
        throw CockpitApplicationServiceException(
          code: 'invalidBundleJson',
          message: 'steps.json must decode to a list.',
          details: <String, Object?>{'path': stepsFile.path},
        );
      }
      for (final item in decoded.cast<Object?>()) {
        if (item is! Map<Object?, Object?>) {
          continue;
        }
        final step = CockpitStepRecord.fromJson(
          Map<String, Object?>.from(item),
        );
        if (step.actionType != 'runtime_event') {
          continue;
        }
        final event = _runtimeEventFromStep(step);
        if (event == null) {
          continue;
        }
        dedupedEvents[event.eventId] = event;
      }
    }

    for (final snapshot in snapshots) {
      final runtime = snapshot.runtime;
      if (runtime == null) {
        continue;
      }
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
      truncated = truncated || runtime.truncated;
      for (final entry in runtime.entries) {
        dedupedEvents[entry.eventId] = entry;
      }
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

    return CockpitBundleRuntimeSummary(
      totalEntryCount:
          totalEntryCount == 0 ? orderedEntries.length : totalEntryCount,
      errorCount: errorCount == 0 ? derivedErrorCount : errorCount,
      warningCount: warningCount == 0 ? derivedWarningCount : warningCount,
      truncated: truncated ||
          (totalEntryCount > 0 && orderedEntries.length < totalEntryCount),
      recentEntries: orderedEntries.take(5).toList(growable: false),
      errorEntries: orderedEntries
          .where((entry) => entry.isError)
          .take(3)
          .toList(growable: false),
    );
  }

  Future<CockpitBundleRebuildSummary?> _readRebuildSummary(
    String bundleDir,
  ) async {
    final snapshots = await _readSnapshotsForNetworkSummary(bundleDir);
    final dedupedEntries = <String, CockpitRebuildEntry>{};
    var totalRebuildCount = 0;
    var uniqueElementCount = 0;
    var truncated = false;

    for (final snapshot in snapshots) {
      final rebuild = snapshot.rebuild;
      if (rebuild == null) {
        continue;
      }
      if (rebuild.totalRebuildCount > totalRebuildCount) {
        totalRebuildCount = rebuild.totalRebuildCount;
      }
      if (rebuild.uniqueElementCount > uniqueElementCount) {
        uniqueElementCount = rebuild.uniqueElementCount;
      }
      truncated = truncated || rebuild.truncated;
      for (final entry in rebuild.entries) {
        final existing = dedupedEntries[entry.signature];
        if (existing == null || existing.rebuildCount < entry.rebuildCount) {
          dedupedEntries[entry.signature] = entry;
        }
      }
    }

    if (dedupedEntries.isEmpty &&
        totalRebuildCount == 0 &&
        uniqueElementCount == 0) {
      return null;
    }

    final orderedEntries = dedupedEntries.values.toList(growable: true)
      ..sort((left, right) {
        final rebuildCompare = right.rebuildCount.compareTo(left.rebuildCount);
        if (rebuildCompare != 0) {
          return rebuildCompare;
        }
        return left.signature.compareTo(right.signature);
      });

    return CockpitBundleRebuildSummary(
      totalRebuildCount: totalRebuildCount == 0
          ? orderedEntries.fold<int>(
              0,
              (count, entry) => count + entry.rebuildCount,
            )
          : totalRebuildCount,
      uniqueElementCount:
          uniqueElementCount == 0 ? orderedEntries.length : uniqueElementCount,
      truncated: truncated ||
          (uniqueElementCount > 0 &&
              orderedEntries.length < uniqueElementCount),
      entries: orderedEntries.take(5).toList(growable: false),
    );
  }

  Future<CockpitBundleAcceptanceEvidence?> _readAcceptanceEvidence(
    String bundleDir,
  ) async {
    final steps = await _readStepRecords(bundleDir);
    for (final step in steps.reversed) {
      final profile = step.requestedCaptureProfile;
      if (profile != CockpitCaptureProfile.acceptance &&
          profile != CockpitCaptureProfile.nativePreferred) {
        continue;
      }
      final evidence = await _acceptanceEvidenceFromStep(bundleDir, step);
      if (evidence != null) {
        return evidence;
      }
    }

    final observations = await _readObservations(bundleDir);
    for (final observation in observations.reversed) {
      final artifactRef = observation.diagnosticsArtifactRef;
      if (artifactRef == null) {
        continue;
      }
      final diagnosticsArtifactPath = p.join(
        bundleDir,
        artifactRef.relativePath,
      );
      final snapshot = await _readDiagnosticSnapshot(diagnosticsArtifactPath);
      if (snapshot == null) {
        continue;
      }
      return _buildAcceptanceEvidence(
        snapshot: snapshot,
        diagnosticsArtifactPath: diagnosticsArtifactPath,
        routeNameOverride: observation.routeName,
      );
    }

    return null;
  }

  Future<CockpitBundleAcceptanceEvidence?> _readBaselineEvidence(
    String bundleDir,
  ) async {
    final steps = await _readStepRecords(bundleDir);
    CockpitStepRecord? fallbackStep;
    for (final step in steps) {
      if (step.actionType != 'captureScreenshot') {
        continue;
      }
      final commandId = step.actionArgs['commandId'] as String?;
      if (commandId == 'baseline_capture') {
        return _acceptanceEvidenceFromStep(bundleDir, step);
      }
      if (fallbackStep == null &&
          step.requestedCaptureProfile != CockpitCaptureProfile.acceptance &&
          step.requestedCaptureProfile !=
              CockpitCaptureProfile.nativePreferred) {
        fallbackStep = step;
      }
    }
    if (fallbackStep != null) {
      return _acceptanceEvidenceFromStep(bundleDir, fallbackStep);
    }
    return null;
  }

  Future<List<CockpitSnapshot>> _readSnapshotsForNetworkSummary(
    String bundleDir,
  ) async {
    final snapshots = <CockpitSnapshot>[];
    final steps = await _readStepRecords(bundleDir);
    for (final step in steps) {
      if (step.snapshot case final snapshot?) {
        snapshots.add(snapshot);
      }
      final diagnosticsArtifactRef = step.snapshot?.diagnosticsArtifactRef;
      if (diagnosticsArtifactRef != null) {
        final diagnosticSnapshot = await _readDiagnosticSnapshot(
          p.join(bundleDir, diagnosticsArtifactRef.relativePath),
        );
        if (diagnosticSnapshot != null) {
          snapshots.add(diagnosticSnapshot);
        }
      }
      for (final artifact in step.artifactRefs) {
        if (artifact.role != 'diagnostics') {
          continue;
        }
        final diagnosticSnapshot = await _readDiagnosticSnapshot(
          p.join(bundleDir, artifact.relativePath),
        );
        if (diagnosticSnapshot != null) {
          snapshots.add(diagnosticSnapshot);
        }
      }
    }
    return snapshots;
  }

  Future<List<CockpitStepRecord>> _readStepRecords(String bundleDir) async {
    final stepsFile = File(p.join(bundleDir, 'steps.json'));
    if (!stepsFile.existsSync()) {
      return const <CockpitStepRecord>[];
    }
    final decoded = jsonDecode(await stepsFile.readAsString());
    if (decoded is! List<Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidBundleJson',
        message: 'steps.json must decode to a list.',
        details: <String, Object?>{'path': stepsFile.path},
      );
    }
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) => CockpitStepRecord.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  Future<List<CockpitObservation>> _readObservations(String bundleDir) async {
    final observationsFile = File(p.join(bundleDir, 'observations.json'));
    if (!observationsFile.existsSync()) {
      return const <CockpitObservation>[];
    }
    final decoded = jsonDecode(await observationsFile.readAsString());
    if (decoded is! List<Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidBundleJson',
        message: 'observations.json must decode to a list.',
        details: <String, Object?>{'path': observationsFile.path},
      );
    }
    return decoded
        .whereType<Map<Object?, Object?>>()
        .map(
          (item) =>
              CockpitObservation.fromJson(Map<String, Object?>.from(item)),
        )
        .toList(growable: false);
  }

  Future<CockpitBundleAcceptanceEvidence?> _acceptanceEvidenceFromStep(
    String bundleDir,
    CockpitStepRecord step,
  ) async {
    final inlineSnapshot = step.snapshot;
    final inlineDiagnosticsPath = step.snapshot?.diagnosticsArtifactRef == null
        ? null
        : p.join(
            bundleDir,
            step.snapshot!.diagnosticsArtifactRef!.relativePath,
          );
    final inlineDiagnosticSnapshot = inlineDiagnosticsPath == null
        ? null
        : await _readDiagnosticSnapshot(inlineDiagnosticsPath);

    CockpitSnapshot? snapshot = inlineDiagnosticSnapshot ?? inlineSnapshot;
    String? diagnosticsArtifactPath = inlineDiagnosticsPath;

    if (snapshot == null) {
      for (final artifact in step.artifactRefs) {
        if (artifact.role != 'diagnostics') {
          continue;
        }
        final candidatePath = p.join(bundleDir, artifact.relativePath);
        final candidateSnapshot = await _readDiagnosticSnapshot(candidatePath);
        if (candidateSnapshot == null) {
          continue;
        }
        snapshot = candidateSnapshot;
        diagnosticsArtifactPath = candidatePath;
        break;
      }
    }

    if (snapshot == null) {
      return null;
    }

    return _buildAcceptanceEvidence(
      snapshot: snapshot,
      diagnosticsArtifactPath: diagnosticsArtifactPath,
    );
  }

  CockpitBundleAcceptanceEvidence _buildAcceptanceEvidence({
    required CockpitSnapshot snapshot,
    required String? diagnosticsArtifactPath,
    String? routeNameOverride,
  }) {
    final network = snapshot.network;
    final runtime = snapshot.runtime;
    final rebuild = snapshot.rebuild;

    return CockpitBundleAcceptanceEvidence(
      routeName: snapshot.routeName ?? routeNameOverride,
      diagnosticLevel: snapshot.diagnosticLevel.jsonValue,
      diagnosticsArtifactPath: diagnosticsArtifactPath,
      visibleTextPreviews: _uniqueNonEmpty(
        snapshot.visibleTargets.map(
          (target) => target.content?.textPreview ?? target.text,
        ),
      ),
      visibleSemanticIds: _uniqueNonEmpty(
        snapshot.visibleTargets.map((target) => target.semanticId),
      ),
      interactiveLabels: _uniqueNonEmpty(
        snapshot.visibleTargets
            .where((target) => target.supportedCommands.isNotEmpty)
            .map(_interactiveLabelForTarget),
      ),
      accessibilityLabels: _acceptanceAccessibilityLabels(snapshot),
      visibleTargetCount: snapshot.visibleTargets.length,
      accessibilityEntryCount:
          snapshot.accessibility?.totalAccessibleTargetCount ??
              snapshot.accessibility?.traversalEntries.length ??
              0,
      hasAccessibilitySummary: snapshot.summary?.accessibilitySummaryIncluded ??
          snapshot.accessibility != null,
      networkEntryCount: network == null
          ? 0
          : (network.capturedEntryCount > 0
              ? network.capturedEntryCount
              : network.totalEntryCount),
      networkFailureCount: network?.failureCount ?? 0,
      networkFailureSignals: network == null
          ? const <CockpitBundleAcceptanceNetworkSignal>[]
          : network.entries
              .where((entry) => entry.isFailure)
              .take(3)
              .map(
                (entry) => CockpitBundleAcceptanceNetworkSignal(
                  requestId: entry.requestId,
                  method: entry.method,
                  uri: entry.uri,
                  statusCode: entry.statusCode,
                  error: entry.error,
                  durationMs: entry.durationMs,
                ),
              )
              .toList(growable: false),
      runtimeEntryCount: runtime == null
          ? 0
          : (runtime.capturedEntryCount > 0
              ? runtime.capturedEntryCount
              : runtime.totalEntryCount),
      runtimeErrorCount: runtime?.errorCount ?? 0,
      runtimeWarningCount: runtime?.warningCount ?? 0,
      runtimeErrorSignals: runtime == null
          ? const <CockpitBundleAcceptanceRuntimeSignal>[]
          : runtime.entries
              .where(
                (entry) => entry.severity == CockpitRuntimeEventSeverity.error,
              )
              .take(3)
              .map(
                (entry) => CockpitBundleAcceptanceRuntimeSignal(
                  eventId: entry.eventId,
                  kind: entry.kind.jsonValue,
                  severity: entry.severity.jsonValue,
                  message: entry.message,
                ),
              )
              .toList(growable: false),
      rebuildTotalCount: rebuild?.totalRebuildCount ?? 0,
      rebuildUniqueElementCount: rebuild?.uniqueElementCount ?? 0,
      rebuildHotspots: rebuild == null
          ? const <CockpitBundleAcceptanceRebuildHotspot>[]
          : rebuild.entries
              .take(3)
              .map(
                (entry) => CockpitBundleAcceptanceRebuildHotspot(
                  signature: entry.signature,
                  routeName: entry.routeName,
                  typeName: entry.typeName,
                  rebuildCount: entry.rebuildCount,
                  keyValue: entry.keyValue,
                  semanticId: entry.semanticId,
                  textPreview: entry.textPreview,
                ),
              )
              .toList(growable: false),
    );
  }

  String? _interactiveLabelForTarget(CockpitSnapshotTarget target) {
    return target.content?.displayLabel ??
        target.text ??
        target.semanticId ??
        target.tooltip ??
        target.keyValue ??
        target.typeName;
  }

  String? _accessibilityLabelFor(CockpitAccessibilityEntry entry) {
    return entry.label ??
        entry.identifier ??
        entry.value ??
        entry.hint ??
        entry.tooltip;
  }

  List<String> _acceptanceAccessibilityLabels(CockpitSnapshot snapshot) {
    final explicitSummaryLabels =
        snapshot.accessibility?.traversalEntries.map(_accessibilityLabelFor) ??
            const <String?>[];
    final diagnosticFallbacks = snapshot.visibleTargets.expand((target) {
      return target.diagnosticProperties
          .where(
            (property) =>
                property.name == 'Semantics Label' ||
                property.name == 'Semantics Identifier' ||
                property.name == 'Semantics Value' ||
                property.name == 'Semantics Hint' ||
                property.name == 'Semantics Tooltip',
          )
          .map((property) => property.value);
    });
    return _uniqueNonEmpty(<String?>[
      ...explicitSummaryLabels,
      ...diagnosticFallbacks,
    ]);
  }

  CockpitBundleAcceptanceDelta _buildAcceptanceDelta({
    required CockpitBundleAcceptanceEvidence baselineEvidence,
    required CockpitBundleAcceptanceEvidence acceptanceEvidence,
  }) {
    final baselineRouteName = baselineEvidence.routeName;
    final acceptanceRouteName = acceptanceEvidence.routeName;
    return CockpitBundleAcceptanceDelta(
      baselineRouteName: baselineRouteName,
      acceptanceRouteName: acceptanceRouteName,
      routeChanged: baselineRouteName != null &&
          acceptanceRouteName != null &&
          baselineRouteName != acceptanceRouteName,
      addedVisibleTextPreviews: _addedItems(
        baselineEvidence.visibleTextPreviews,
        acceptanceEvidence.visibleTextPreviews,
      ),
      removedVisibleTextPreviews: _removedItems(
        baselineEvidence.visibleTextPreviews,
        acceptanceEvidence.visibleTextPreviews,
      ),
      addedSemanticIds: _addedItems(
        baselineEvidence.visibleSemanticIds,
        acceptanceEvidence.visibleSemanticIds,
      ),
      removedSemanticIds: _removedItems(
        baselineEvidence.visibleSemanticIds,
        acceptanceEvidence.visibleSemanticIds,
      ),
      addedInteractiveLabels: _addedItems(
        baselineEvidence.interactiveLabels,
        acceptanceEvidence.interactiveLabels,
      ),
      removedInteractiveLabels: _removedItems(
        baselineEvidence.interactiveLabels,
        acceptanceEvidence.interactiveLabels,
      ),
      addedAccessibilityLabels: _addedItems(
        baselineEvidence.accessibilityLabels,
        acceptanceEvidence.accessibilityLabels,
      ),
      removedAccessibilityLabels: _removedItems(
        baselineEvidence.accessibilityLabels,
        acceptanceEvidence.accessibilityLabels,
      ),
      networkFailureDeltaCount: acceptanceEvidence.networkFailureCount -
          baselineEvidence.networkFailureCount,
      newNetworkFailureSignals: _newNetworkFailureSignals(
        baselineEvidence.networkFailureSignals,
        acceptanceEvidence.networkFailureSignals,
      ),
      runtimeErrorDeltaCount: acceptanceEvidence.runtimeErrorCount -
          baselineEvidence.runtimeErrorCount,
      newRuntimeErrorSignals: _newRuntimeErrorSignals(
        baselineEvidence.runtimeErrorSignals,
        acceptanceEvidence.runtimeErrorSignals,
      ),
      rebuildTotalDeltaCount: acceptanceEvidence.rebuildTotalCount -
          baselineEvidence.rebuildTotalCount,
      rebuildUniqueElementDeltaCount:
          acceptanceEvidence.rebuildUniqueElementCount -
              baselineEvidence.rebuildUniqueElementCount,
      newRebuildHotspots: _newRebuildHotspots(
        baselineEvidence.rebuildHotspots,
        acceptanceEvidence.rebuildHotspots,
      ),
    );
  }

  bool _isAcceptanceComparisonReady({
    required CockpitBundleAcceptanceEvidence? baselineEvidence,
    required CockpitBundleAcceptanceEvidence? acceptanceEvidence,
    required CockpitBundleAcceptanceDelta? acceptanceDelta,
  }) {
    if (baselineEvidence == null ||
        acceptanceEvidence == null ||
        acceptanceDelta == null) {
      return false;
    }
    return baselineEvidence.hasComparableSignals &&
        acceptanceEvidence.hasComparableSignals;
  }

  CockpitBundleGateSummary _buildBundleGateSummary({
    required CockpitRunManifest manifest,
    required Map<String, Object?> handoff,
    required Map<String, Object?> delivery,
    required CockpitBundleAcceptanceEvidence? baselineEvidence,
    required CockpitBundleAcceptanceEvidence? acceptanceEvidence,
    required CockpitBundleAcceptanceDelta? acceptanceDelta,
  }) {
    final screenshotFailureCodes = _deliveryArtifactFailureCodes(
      manifest: manifest,
      delivery: delivery,
    );
    final recordingFailureCodes = _deliveryVideoFailureCodes(
      manifest: manifest,
      handoff: handoff,
      delivery: delivery,
    );
    final acceptanceEvidenceFailureCodes = _acceptanceEvidenceFailureCodes(
      baselineEvidence: baselineEvidence,
      acceptanceEvidence: acceptanceEvidence,
      acceptanceDelta: acceptanceDelta,
    );
    final screenshotReady = manifest.deliveryArtifactsReady;
    final recordingReadyOrExplained = manifest.deliveryVideoReady;
    final deliveryValidated = screenshotReady && recordingReadyOrExplained;
    final finalAssertionPassed = manifest.status != CockpitTaskStatus.failed &&
        manifest.runtimeErrorCount == 0;

    final failureCodes = <CockpitTaskGate, List<String>>{};
    if (!screenshotReady) {
      failureCodes[CockpitTaskGate.screenshotReady] = screenshotFailureCodes;
    }
    if (!recordingReadyOrExplained) {
      failureCodes[CockpitTaskGate.recordingReadyOrExplained] =
          recordingFailureCodes;
    }
    if (!deliveryValidated) {
      failureCodes[CockpitTaskGate.deliveryValidated] = _mergeFailureCodes(
        screenshotFailureCodes,
        recordingFailureCodes,
      );
    }
    if (acceptanceEvidenceFailureCodes.isNotEmpty) {
      failureCodes[CockpitTaskGate.acceptanceEvidenceReadable] =
          acceptanceEvidenceFailureCodes;
    }
    if (!finalAssertionPassed) {
      failureCodes[CockpitTaskGate.finalAssertionPassed] = <String>[
        if (manifest.runtimeErrorCount > 0)
          'runtimeErrorsDetected'
        else
          'taskFailed',
      ];
    }
    final baselineCollected = baselineEvidence != null ||
        manifest.screenshotCount > 0 ||
        (delivery['primaryScreenshotRef'] as String?)?.isNotEmpty == true;
    if (!baselineCollected) {
      failureCodes[CockpitTaskGate.baselineCollected] = const <String>[
        'baselineEvidenceMissing',
      ];
    }

    return CockpitBundleGateSummary(
      gates: <CockpitTaskGate, bool>{
        CockpitTaskGate.sessionReachable: true,
        CockpitTaskGate.baselineCollected: baselineCollected,
        CockpitTaskGate.executionFinished: true,
        CockpitTaskGate.bundleWritten: true,
        CockpitTaskGate.deliveryValidated: deliveryValidated,
        CockpitTaskGate.acceptanceEvidenceReadable:
            acceptanceEvidenceFailureCodes.isEmpty,
        CockpitTaskGate.screenshotReady: screenshotReady,
        CockpitTaskGate.recordingReadyOrExplained: recordingReadyOrExplained,
        CockpitTaskGate.finalAssertionPassed: finalAssertionPassed,
      },
      failureCodes: failureCodes,
    );
  }

  List<String> _deliveryArtifactFailureCodes({
    required CockpitRunManifest manifest,
    required Map<String, Object?> delivery,
  }) {
    if (manifest.deliveryArtifactFailureCodes.isNotEmpty ||
        manifest.deliveryArtifactsReady) {
      return manifest.deliveryArtifactFailureCodes;
    }
    final primaryScreenshotRef = delivery['primaryScreenshotRef'] as String?;
    return <String>[
      if (primaryScreenshotRef == null || primaryScreenshotRef.isEmpty)
        'primaryScreenshotMissing'
      else
        'acceptanceScreenshotMissing',
    ];
  }

  List<String> _deliveryVideoFailureCodes({
    required CockpitRunManifest manifest,
    required Map<String, Object?> handoff,
    required Map<String, Object?> delivery,
  }) {
    if (manifest.deliveryVideoFailureCodes.isNotEmpty ||
        manifest.deliveryVideoReady) {
      return manifest.deliveryVideoFailureCodes;
    }
    final primaryRecordingRef = delivery['primaryRecordingRef'] as String?;
    final recordingFailureReason =
        handoff['recordingFailureReason'] as String? ??
            _readNestedString(
              delivery,
              'readiness',
              'video',
              'failureReason',
            );
    return <String>[
      if (recordingFailureReason != null && recordingFailureReason.isNotEmpty)
        'recordingFailed'
      else if (primaryRecordingRef == null || primaryRecordingRef.isEmpty)
        'primaryRecordingMissing'
      else
        'acceptanceRecordingMissing',
    ];
  }

  List<String> _acceptanceEvidenceFailureCodes({
    required CockpitBundleAcceptanceEvidence? baselineEvidence,
    required CockpitBundleAcceptanceEvidence? acceptanceEvidence,
    required CockpitBundleAcceptanceDelta? acceptanceDelta,
  }) {
    final failures = <String>[
      if (baselineEvidence == null) 'baselineEvidenceMissing',
      if (acceptanceEvidence == null) 'acceptanceEvidenceMissing',
      if (acceptanceDelta == null) 'acceptanceDeltaMissing',
      if (baselineEvidence != null && !baselineEvidence.hasComparableSignals)
        'baselineComparableSignalsMissing',
      if (acceptanceEvidence != null &&
          !acceptanceEvidence.hasComparableSignals)
        'acceptanceComparableSignalsMissing',
    ];
    return List<String>.unmodifiable(failures);
  }

  List<String> _mergeFailureCodes(List<String> left, List<String> right) {
    return List<String>.unmodifiable(<String>{...left, ...right});
  }

  String? _readNestedString(
    Map<String, Object?> source,
    String firstKey,
    String secondKey,
    String thirdKey,
  ) {
    final first = source[firstKey];
    if (first is! Map<Object?, Object?>) {
      return null;
    }
    final second = first[secondKey];
    if (second is! Map<Object?, Object?>) {
      return null;
    }
    final value = second[thirdKey];
    return value is String ? value : null;
  }

  List<String> _addedItems(List<String> baseline, List<String> acceptance) {
    final baselineSet = baseline.toSet();
    return acceptance
        .where((item) => !baselineSet.contains(item))
        .toList(growable: false);
  }

  List<String> _removedItems(List<String> baseline, List<String> acceptance) {
    final acceptanceSet = acceptance.toSet();
    return baseline
        .where((item) => !acceptanceSet.contains(item))
        .toList(growable: false);
  }

  List<CockpitBundleAcceptanceNetworkSignal> _newNetworkFailureSignals(
    List<CockpitBundleAcceptanceNetworkSignal> baseline,
    List<CockpitBundleAcceptanceNetworkSignal> acceptance,
  ) {
    final baselineKeys = baseline.map(_networkSignalKey).toSet();
    return acceptance
        .where((signal) => !baselineKeys.contains(_networkSignalKey(signal)))
        .toList(growable: false);
  }

  String _networkSignalKey(CockpitBundleAcceptanceNetworkSignal signal) {
    return '${signal.method}|${signal.uri}|${signal.statusCode}|${signal.error}';
  }

  List<CockpitBundleAcceptanceRuntimeSignal> _newRuntimeErrorSignals(
    List<CockpitBundleAcceptanceRuntimeSignal> baseline,
    List<CockpitBundleAcceptanceRuntimeSignal> acceptance,
  ) {
    final baselineKeys = baseline.map(_runtimeSignalKey).toSet();
    return acceptance
        .where((signal) => !baselineKeys.contains(_runtimeSignalKey(signal)))
        .toList(growable: false);
  }

  String _runtimeSignalKey(CockpitBundleAcceptanceRuntimeSignal signal) {
    return '${signal.kind}|${signal.severity}|${signal.message}';
  }

  List<CockpitBundleAcceptanceRebuildHotspot> _newRebuildHotspots(
    List<CockpitBundleAcceptanceRebuildHotspot> baseline,
    List<CockpitBundleAcceptanceRebuildHotspot> acceptance,
  ) {
    final baselineKeys = baseline.map((hotspot) => hotspot.signature).toSet();
    return acceptance
        .where((hotspot) => !baselineKeys.contains(hotspot.signature))
        .toList(growable: false);
  }

  List<String> _uniqueNonEmpty(Iterable<String?> values, {int max = 8}) {
    final items = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized == null || normalized.isEmpty || !seen.add(normalized)) {
        continue;
      }
      items.add(normalized);
      if (items.length >= max) {
        break;
      }
    }
    return List<String>.unmodifiable(items);
  }

  Future<CockpitSnapshot?> _readDiagnosticSnapshot(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<Object?, Object?>) {
      throw CockpitApplicationServiceException(
        code: 'invalidBundleJson',
        message: 'Diagnostic snapshot JSON must decode to an object.',
        details: <String, Object?>{'path': path},
      );
    }
    return CockpitSnapshot.fromJson(Map<String, Object?>.from(decoded));
  }

  CockpitRuntimeEvent? _runtimeEventFromStep(CockpitStepRecord step) {
    final eventId = step.actionArgs['eventId'] as String?;
    final kind = step.actionArgs['kind'];
    final severity = step.actionArgs['severity'];
    final message = step.actionArgs['message'] as String?;
    if (eventId == null ||
        kind == null ||
        severity == null ||
        message == null) {
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
}
