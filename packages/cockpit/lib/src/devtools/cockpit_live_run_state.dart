import 'cockpit_live_run_event.dart';

final class CockpitLiveRunState {
  const CockpitLiveRunState({
    this.schemaVersion = 1,
    required this.runId,
    this.displayName,
    required this.status,
    required this.startedAt,
    required this.updatedAt,
    this.finishedAt,
    this.workspaceId,
    this.scopeId,
    this.scopeKind,
    this.scopeLabel,
    this.sessionId,
    this.taskId,
    this.platform,
    this.stage,
    this.currentStep,
    this.counts = const <String, int>{},
    this.recording,
    this.recentArtifacts = const <Map<String, Object?>>[],
    this.lastError,
    this.bundleDir,
    this.recommendedNextStep,
  });

  factory CockpitLiveRunState.initial({
    required String runId,
    String? displayName,
    String status = 'running',
    required DateTime startedAt,
    String? workspaceId,
    String? scopeId,
    String? scopeKind,
    String? scopeLabel,
    String? sessionId,
    String? taskId,
    String? platform,
    String? recommendedNextStep,
  }) {
    return CockpitLiveRunState(
      runId: runId,
      displayName: displayName,
      status: status,
      startedAt: startedAt.toUtc(),
      updatedAt: startedAt.toUtc(),
      workspaceId: workspaceId,
      scopeId: scopeId,
      scopeKind: scopeKind,
      scopeLabel: scopeLabel,
      sessionId: sessionId,
      taskId: taskId,
      platform: platform,
      counts: const <String, int>{
        'eventCount': 0,
        'errorCount': 0,
        'artifactCount': 0,
      },
      recommendedNextStep: recommendedNextStep,
    );
  }

  final int schemaVersion;
  final String runId;
  final String? displayName;
  final String status;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? finishedAt;
  final String? workspaceId;
  final String? scopeId;
  final String? scopeKind;
  final String? scopeLabel;
  final String? sessionId;
  final String? taskId;
  final String? platform;
  final String? stage;
  final Map<String, Object?>? currentStep;
  final Map<String, int> counts;
  final Map<String, Object?>? recording;
  final List<Map<String, Object?>> recentArtifacts;
  final Map<String, Object?>? lastError;
  final String? bundleDir;
  final String? recommendedNextStep;

  CockpitLiveRunState copyWith({
    String? status,
    DateTime? updatedAt,
    DateTime? finishedAt,
    String? stage,
    Map<String, Object?>? currentStep,
    Map<String, int>? counts,
    Map<String, Object?>? recording,
    List<Map<String, Object?>>? recentArtifacts,
    Map<String, Object?>? lastError,
    String? bundleDir,
    String? recommendedNextStep,
  }) {
    return CockpitLiveRunState(
      schemaVersion: schemaVersion,
      runId: runId,
      displayName: displayName,
      status: status ?? this.status,
      startedAt: startedAt,
      updatedAt: (updatedAt ?? this.updatedAt).toUtc(),
      finishedAt: finishedAt ?? this.finishedAt,
      workspaceId: workspaceId,
      scopeId: scopeId,
      scopeKind: scopeKind,
      scopeLabel: scopeLabel,
      sessionId: sessionId,
      taskId: taskId,
      platform: platform,
      stage: stage ?? this.stage,
      currentStep: currentStep ?? this.currentStep,
      counts: counts ?? this.counts,
      recording: recording ?? this.recording,
      recentArtifacts: recentArtifacts ?? this.recentArtifacts,
      lastError: lastError ?? this.lastError,
      bundleDir: bundleDir ?? this.bundleDir,
      recommendedNextStep: recommendedNextStep ?? this.recommendedNextStep,
    );
  }

  CockpitLiveRunState applyEvent(
    CockpitLiveRunEvent event, {
    int recentArtifactLimit = 20,
  }) {
    final nextCounts = <String, int>{...counts};
    nextCounts['eventCount'] = (nextCounts['eventCount'] ?? 0) + 1;
    final artifactRefs = <Map<String, Object?>>[
      ...event.artifactRefs,
      ...event.captureRefs,
    ];
    if (artifactRefs.isNotEmpty) {
      nextCounts['artifactCount'] =
          (nextCounts['artifactCount'] ?? 0) + artifactRefs.length;
    }
    final error = event.error;
    if (error != null || event.status == 'failed') {
      nextCounts['errorCount'] = (nextCounts['errorCount'] ?? 0) + 1;
    }

    final nextArtifacts = <Map<String, Object?>>[
      ...recentArtifacts,
      for (final artifact in artifactRefs)
        <String, Object?>{
          ...artifact,
          'eventSeq': event.seq,
          'capturedAt': event.timestamp.toUtc().toIso8601String(),
        },
    ];
    final boundedArtifacts = nextArtifacts.length <= recentArtifactLimit
        ? nextArtifacts
        : nextArtifacts.sublist(nextArtifacts.length - recentArtifactLimit);

    final nextStatus = _nextRunStatus(this, event);
    return copyWith(
      status: nextStatus,
      updatedAt: event.timestamp,
      finishedAt: _isTerminalStatus(nextStatus) ? event.timestamp : null,
      stage: event.stage,
      currentStep: _currentStepFor(event),
      counts: nextCounts,
      recentArtifacts: boundedArtifacts,
      lastError: error,
      bundleDir: event.bundleDir,
      recommendedNextStep: event.recommendedNextStep,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'runId': runId,
      if (displayName != null) 'displayName': displayName,
      'status': status,
      'startedAt': startedAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (finishedAt != null)
        'finishedAt': finishedAt!.toUtc().toIso8601String(),
      if (workspaceId != null) 'workspaceId': workspaceId,
      if (scopeId != null) 'scopeId': scopeId,
      if (scopeKind != null) 'scopeKind': scopeKind,
      if (scopeLabel != null) 'scopeLabel': scopeLabel,
      if (sessionId != null) 'sessionId': sessionId,
      if (taskId != null) 'taskId': taskId,
      if (platform != null) 'platform': platform,
      if (stage != null) 'stage': stage,
      if (currentStep != null) 'currentStep': currentStep,
      'counts': counts,
      if (recording != null) 'recording': recording,
      if (recentArtifacts.isNotEmpty) 'recentArtifacts': recentArtifacts,
      if (lastError != null) 'lastError': lastError,
      if (bundleDir != null) 'bundleDir': bundleDir,
      if (recommendedNextStep != null)
        'recommendedNextStep': recommendedNextStep,
    };
  }

  factory CockpitLiveRunState.fromJson(Map<String, Object?> json) {
    return CockpitLiveRunState(
      schemaVersion: _intValue(json['schemaVersion']) ?? 1,
      runId: json['runId'] as String,
      displayName: json['displayName'] as String?,
      status: json['status'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      finishedAt: json['finishedAt'] is String
          ? DateTime.parse(json['finishedAt']! as String).toUtc()
          : null,
      workspaceId: json['workspaceId'] as String?,
      scopeId: json['scopeId'] as String?,
      scopeKind: json['scopeKind'] as String?,
      scopeLabel: json['scopeLabel'] as String?,
      sessionId: json['sessionId'] as String?,
      taskId: json['taskId'] as String?,
      platform: json['platform'] as String?,
      stage: json['stage'] as String?,
      currentStep: _mapValue(json['currentStep']),
      counts:
          _mapValue(json['counts'])?.map(
            (key, value) =>
                MapEntry<String, int>(key, value is num ? value.toInt() : 0),
          ) ??
          const <String, int>{},
      recording: _mapValue(json['recording']),
      recentArtifacts: _mapList(json['recentArtifacts']),
      lastError: _mapValue(json['lastError']),
      bundleDir: json['bundleDir'] as String?,
      recommendedNextStep: json['recommendedNextStep'] as String?,
    );
  }
}

String _nextRunStatus(CockpitLiveRunState current, CockpitLiveRunEvent event) {
  return switch (event.type) {
    'run_started' => 'running',
    'run_finished' || 'bundle_written' => event.status,
    _ => current.status,
  };
}

Map<String, Object?>? _currentStepFor(CockpitLiveRunEvent event) {
  if (event.workflowStepId == null &&
      event.workflowStepType == null &&
      event.commandId == null &&
      event.commandType == null &&
      event.description == null) {
    return null;
  }
  return <String, Object?>{
    if (event.workflowStepId != null) 'workflowStepId': event.workflowStepId,
    if (event.workflowStepType != null)
      'workflowStepType': event.workflowStepType,
    if (event.description != null) 'description': event.description,
    if (event.commandId != null) 'commandId': event.commandId,
    if (event.commandType != null) 'commandType': event.commandType,
    if (event.stage != null) 'stage': event.stage,
  };
}

bool _isTerminalStatus(String status) {
  return status == 'succeeded' ||
      status == 'completed' ||
      status == 'failed' ||
      status == 'canceled' ||
      status == 'cancelled';
}

int? _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

List<Map<String, Object?>> _mapList(Object? value) {
  if (value is! List) {
    return const <Map<String, Object?>>[];
  }
  return value
      .whereType<Map>()
      .map(
        (entry) => entry.map(
          (key, value) => MapEntry<String, Object?>(key.toString(), value),
        ),
      )
      .toList(growable: false);
}

Map<String, Object?>? _mapValue(Object? value) {
  if (value is! Map) {
    return null;
  }
  return value.map(
    (key, value) => MapEntry<String, Object?>(key.toString(), value),
  );
}
