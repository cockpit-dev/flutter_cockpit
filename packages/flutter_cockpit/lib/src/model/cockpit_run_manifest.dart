import 'package:collection/collection.dart';

import 'cockpit_artifact_ref.dart';
import 'cockpit_task_status.dart';

final class CockpitRunManifest {
  CockpitRunManifest({
    required this.sessionId,
    required this.taskId,
    required this.platform,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    List<CockpitArtifactRef> artifactRefs = const [],
    this.failureSummary,
    List<String> capabilitiesUsed = const [],
    this.commandCount = 0,
    this.screenshotCount = 0,
    this.failureCount = 0,
    this.nativeScreenshotCount = 0,
    this.flutterScreenshotCount = 0,
    this.deliveryArtifactsReady = false,
    this.recordingCount = 0,
    this.nativeRecordingCount = 0,
    this.deliveryVideoReady = false,
    this.runtimeEventCount = 0,
    this.runtimeErrorCount = 0,
    this.runtimeWarningCount = 0,
  })  : artifactRefs = List.unmodifiable(artifactRefs),
        capabilitiesUsed = List.unmodifiable(capabilitiesUsed);

  final String sessionId;
  final String taskId;
  final String platform;
  final CockpitTaskStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final List<CockpitArtifactRef> artifactRefs;
  final String? failureSummary;
  final List<String> capabilitiesUsed;
  final int commandCount;
  final int screenshotCount;
  final int failureCount;
  final int nativeScreenshotCount;
  final int flutterScreenshotCount;
  final bool deliveryArtifactsReady;
  final int recordingCount;
  final int nativeRecordingCount;
  final bool deliveryVideoReady;
  final int runtimeEventCount;
  final int runtimeErrorCount;
  final int runtimeWarningCount;

  static const ListEquality<CockpitArtifactRef> _artifactListEquality =
      ListEquality<CockpitArtifactRef>();
  static const ListEquality<String> _stringListEquality =
      ListEquality<String>();

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'taskId': taskId,
        'platform': platform,
        'status': status.name,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'finishedAt': finishedAt?.toUtc().toIso8601String(),
        'artifactRefs':
            artifactRefs.map((artifact) => artifact.toJson()).toList(),
        'failureSummary': failureSummary,
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
      };

  factory CockpitRunManifest.fromJson(Map<String, Object?> json) {
    final artifactRefs =
        (json['artifactRefs'] as List<Object?>? ?? const <Object?>[])
            .cast<Map<Object?, Object?>>()
            .map(
              (item) =>
                  CockpitArtifactRef.fromJson(Map<String, Object?>.from(item)),
            )
            .toList();

    return CockpitRunManifest(
      sessionId: json['sessionId']! as String,
      taskId: json['taskId']! as String,
      platform: json['platform']! as String,
      status: CockpitTaskStatus.fromJson(json['status']),
      startedAt: DateTime.parse(json['startedAt']! as String).toUtc(),
      finishedAt: json['finishedAt'] == null
          ? null
          : DateTime.parse(json['finishedAt']! as String).toUtc(),
      artifactRefs: artifactRefs,
      failureSummary: json['failureSummary'] as String?,
      capabilitiesUsed:
          (json['capabilitiesUsed'] as List<Object?>? ?? const <Object?>[])
              .cast<String>(),
      commandCount: json['commandCount'] as int? ?? 0,
      screenshotCount: json['screenshotCount'] as int? ?? 0,
      failureCount: json['failureCount'] as int? ?? 0,
      nativeScreenshotCount: json['nativeScreenshotCount'] as int? ?? 0,
      flutterScreenshotCount: json['flutterScreenshotCount'] as int? ?? 0,
      deliveryArtifactsReady: json['deliveryArtifactsReady'] as bool? ?? false,
      recordingCount: json['recordingCount'] as int? ?? 0,
      nativeRecordingCount: json['nativeRecordingCount'] as int? ?? 0,
      deliveryVideoReady: json['deliveryVideoReady'] as bool? ?? false,
      runtimeEventCount: json['runtimeEventCount'] as int? ?? 0,
      runtimeErrorCount: json['runtimeErrorCount'] as int? ?? 0,
      runtimeWarningCount: json['runtimeWarningCount'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitRunManifest &&
            other.sessionId == sessionId &&
            other.taskId == taskId &&
            other.platform == platform &&
            other.status == status &&
            other.startedAt == startedAt &&
            other.finishedAt == finishedAt &&
            other.failureSummary == failureSummary &&
            other.commandCount == commandCount &&
            other.screenshotCount == screenshotCount &&
            other.failureCount == failureCount &&
            other.nativeScreenshotCount == nativeScreenshotCount &&
            other.flutterScreenshotCount == flutterScreenshotCount &&
            other.deliveryArtifactsReady == deliveryArtifactsReady &&
            other.recordingCount == recordingCount &&
            other.nativeRecordingCount == nativeRecordingCount &&
            other.deliveryVideoReady == deliveryVideoReady &&
            other.runtimeEventCount == runtimeEventCount &&
            other.runtimeErrorCount == runtimeErrorCount &&
            other.runtimeWarningCount == runtimeWarningCount &&
            _stringListEquality.equals(
              other.capabilitiesUsed,
              capabilitiesUsed,
            ) &&
            _artifactListEquality.equals(other.artifactRefs, artifactRefs);
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        sessionId,
        taskId,
        platform,
        status,
        startedAt,
        finishedAt,
        failureSummary,
        commandCount,
        screenshotCount,
        failureCount,
        nativeScreenshotCount,
        flutterScreenshotCount,
        deliveryArtifactsReady,
        recordingCount,
        nativeRecordingCount,
        deliveryVideoReady,
        runtimeEventCount,
        runtimeErrorCount,
        runtimeWarningCount,
        _stringListEquality.hash(capabilitiesUsed),
        _artifactListEquality.hash(artifactRefs),
      ]);
}
