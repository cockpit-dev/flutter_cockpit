import 'cockpit_latest_task_store.dart';
import 'cockpit_session_registry.dart';

final class CockpitRuntimeErrorEntry {
  const CockpitRuntimeErrorEntry({
    required this.source,
    required this.message,
    this.recordedAt,
    this.sessionId,
    this.bundleDir,
    this.kind,
    this.routeName,
  });

  final String source;
  final String message;
  final DateTime? recordedAt;
  final String? sessionId;
  final String? bundleDir;
  final String? kind;
  final String? routeName;

  Map<String, Object?> toJson() => <String, Object?>{
        'source': source,
        'message': message,
        'recordedAt': recordedAt?.toUtc().toIso8601String(),
        'sessionId': sessionId,
        'bundleDir': bundleDir,
        'kind': kind,
        'routeName': routeName,
      };
}

final class CockpitReadRuntimeErrorsRequest {
  const CockpitReadRuntimeErrorsRequest({
    this.includeLatestTask = true,
    this.includeSessions = true,
  });

  final bool includeLatestTask;
  final bool includeSessions;
}

final class CockpitReadRuntimeErrorsResult {
  const CockpitReadRuntimeErrorsResult({required this.errors});

  final List<CockpitRuntimeErrorEntry> errors;

  bool get hasErrors => errors.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'hasErrors': hasErrors,
        'errors': errors.map((error) => error.toJson()).toList(growable: false),
      };
}

final class CockpitReadRuntimeErrorsService {
  const CockpitReadRuntimeErrorsService({
    required CockpitSessionRegistry registry,
    required CockpitLatestTaskStore latestTaskStore,
  })  : _registry = registry,
        _latestTaskStore = latestTaskStore;

  final CockpitSessionRegistry _registry;
  final CockpitLatestTaskStore _latestTaskStore;

  CockpitReadRuntimeErrorsResult read(
    CockpitReadRuntimeErrorsRequest request,
  ) {
    final errors = <CockpitRuntimeErrorEntry>[];
    if (request.includeSessions) {
      final snapshot = _registry.snapshot();
      for (final record in snapshot.developmentSessions) {
        final lastError = record.status.lastError;
        if (lastError == null || lastError.isEmpty) {
          continue;
        }
        errors.add(
          CockpitRuntimeErrorEntry(
            source: 'development_session',
            message: lastError,
            recordedAt: record.updatedAt,
            sessionId: record.handle.developmentSessionId,
          ),
        );
      }
    }
    if (request.includeLatestTask) {
      final latest = _latestTaskStore.latest;
      final runtimeErrors =
          latest?.bundleSummary?.runtimeSummary?.errorEntries ?? const [];
      for (final event in runtimeErrors) {
        errors.add(
          CockpitRuntimeErrorEntry(
            source: 'latest_task_bundle',
            message: event.message,
            recordedAt: event.recordedAt,
            bundleDir: latest?.bundleSummary?.bundleDir,
            kind: event.kind.jsonValue,
            routeName: event.routeName,
          ),
        );
      }
    }
    errors.sort((left, right) {
      final leftAt = left.recordedAt;
      final rightAt = right.recordedAt;
      if (leftAt == null && rightAt == null) {
        return 0;
      }
      if (leftAt == null) {
        return 1;
      }
      if (rightAt == null) {
        return -1;
      }
      return rightAt.compareTo(leftAt);
    });
    return CockpitReadRuntimeErrorsResult(
      errors: List<CockpitRuntimeErrorEntry>.unmodifiable(errors),
    );
  }
}
