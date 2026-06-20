final class CockpitLiveRunEvent {
  const CockpitLiveRunEvent({
    this.schemaVersion = 1,
    required this.runId,
    required this.seq,
    required this.timestamp,
    required this.type,
    required this.status,
    this.workspaceId,
    this.scopeId,
    this.scopeKind,
    this.scopeLabel,
    this.sessionId,
    this.taskId,
    this.platform,
    this.stage,
    this.workflowStepId,
    this.workflowStepType,
    this.description,
    this.commandId,
    this.commandType,
    this.artifactRefs = const <Map<String, Object?>>[],
    this.captureRefs = const <Map<String, Object?>>[],
    this.error,
    this.bundleDir,
    this.recommendedNextStep,
    this.details = const <String, Object?>{},
  });

  final int schemaVersion;
  final String runId;
  final int seq;
  final DateTime timestamp;
  final String type;
  final String status;
  final String? workspaceId;
  final String? scopeId;
  final String? scopeKind;
  final String? scopeLabel;
  final String? sessionId;
  final String? taskId;
  final String? platform;
  final String? stage;
  final String? workflowStepId;
  final String? workflowStepType;
  final String? description;
  final String? commandId;
  final String? commandType;
  final List<Map<String, Object?>> artifactRefs;
  final List<Map<String, Object?>> captureRefs;
  final Map<String, Object?>? error;
  final String? bundleDir;
  final String? recommendedNextStep;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': schemaVersion,
      'runId': runId,
      'seq': seq,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'type': type,
      'status': status,
      if (workspaceId != null) 'workspaceId': workspaceId,
      if (scopeId != null) 'scopeId': scopeId,
      if (scopeKind != null) 'scopeKind': scopeKind,
      if (scopeLabel != null) 'scopeLabel': scopeLabel,
      if (sessionId != null) 'sessionId': sessionId,
      if (taskId != null) 'taskId': taskId,
      if (platform != null) 'platform': platform,
      if (stage != null) 'stage': stage,
      if (workflowStepId != null) 'workflowStepId': workflowStepId,
      if (workflowStepType != null) 'workflowStepType': workflowStepType,
      if (description != null) 'description': description,
      if (commandId != null) 'commandId': commandId,
      if (commandType != null) 'commandType': commandType,
      if (artifactRefs.isNotEmpty) 'artifactRefs': artifactRefs,
      if (captureRefs.isNotEmpty) 'captureRefs': captureRefs,
      if (error != null) 'error': error,
      if (bundleDir != null) 'bundleDir': bundleDir,
      if (recommendedNextStep != null)
        'recommendedNextStep': recommendedNextStep,
      if (details.isNotEmpty) 'details': details,
    };
  }

  factory CockpitLiveRunEvent.fromJson(Map<String, Object?> json) {
    return CockpitLiveRunEvent(
      schemaVersion: _intValue(json['schemaVersion']) ?? 1,
      runId: json['runId'] as String,
      seq: _intValue(json['seq'])!,
      timestamp: DateTime.parse(json['timestamp'] as String).toUtc(),
      type: json['type'] as String,
      status: json['status'] as String,
      workspaceId: json['workspaceId'] as String?,
      scopeId: json['scopeId'] as String?,
      scopeKind: json['scopeKind'] as String?,
      scopeLabel: json['scopeLabel'] as String?,
      sessionId: json['sessionId'] as String?,
      taskId: json['taskId'] as String?,
      platform: json['platform'] as String?,
      stage: json['stage'] as String?,
      workflowStepId: json['workflowStepId'] as String?,
      workflowStepType: json['workflowStepType'] as String?,
      description: json['description'] as String?,
      commandId: json['commandId'] as String?,
      commandType: json['commandType'] as String?,
      artifactRefs: _mapList(json['artifactRefs']),
      captureRefs: _mapList(json['captureRefs']),
      error: _mapValue(json['error']),
      bundleDir: json['bundleDir'] as String?,
      recommendedNextStep: json['recommendedNextStep'] as String?,
      details: _mapValue(json['details']) ?? const <String, Object?>{},
    );
  }
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
