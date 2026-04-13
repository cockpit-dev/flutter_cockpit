import 'package:flutter/foundation.dart';

enum TodoSyncStatus {
  idle,
  checking,
  healthy,
  syncing,
  synced,
  failed,
  conflicted
}

@immutable
final class TodoSyncState {
  const TodoSyncState({
    this.status = TodoSyncStatus.idle,
    this.headline = 'Sync relay idle',
    this.detail = 'Run a relay check to capture request and response evidence.',
    this.simulateFailure = false,
    this.endpoint,
    this.statusCode,
    this.checkedAt,
    this.lastHealthySummary,
    this.lastHealthyEndpoint,
    this.lastHealthyStatusCode,
    this.lastHealthyCheckedAt,
    this.pendingTaskCount = 0,
    this.failedTaskCount = 0,
    this.conflictTaskCount = 0,
    this.lastRunSummary,
  });

  final TodoSyncStatus status;
  final String headline;
  final String detail;
  final bool simulateFailure;
  final String? endpoint;
  final int? statusCode;
  final DateTime? checkedAt;
  final String? lastHealthySummary;
  final String? lastHealthyEndpoint;
  final int? lastHealthyStatusCode;
  final DateTime? lastHealthyCheckedAt;
  final int pendingTaskCount;
  final int failedTaskCount;
  final int conflictTaskCount;
  final String? lastRunSummary;

  bool get isChecking => status == TodoSyncStatus.checking;
  bool get hasSuccessfulCheck => lastHealthySummary != null;
  String get actionLabel {
    if (isChecking) {
      return 'Checking…';
    }
    return status == TodoSyncStatus.failed ? 'Retry now' : 'Run check';
  }

  TodoSyncState copyWith({
    TodoSyncStatus? status,
    String? headline,
    String? detail,
    bool? simulateFailure,
    ValueGetter<String?>? endpoint,
    ValueGetter<int?>? statusCode,
    ValueGetter<DateTime?>? checkedAt,
    ValueGetter<String?>? lastHealthySummary,
    ValueGetter<String?>? lastHealthyEndpoint,
    ValueGetter<int?>? lastHealthyStatusCode,
    ValueGetter<DateTime?>? lastHealthyCheckedAt,
    int? pendingTaskCount,
    int? failedTaskCount,
    int? conflictTaskCount,
    ValueGetter<String?>? lastRunSummary,
  }) {
    return TodoSyncState(
      status: status ?? this.status,
      headline: headline ?? this.headline,
      detail: detail ?? this.detail,
      simulateFailure: simulateFailure ?? this.simulateFailure,
      endpoint: endpoint == null ? this.endpoint : endpoint(),
      statusCode: statusCode == null ? this.statusCode : statusCode(),
      checkedAt: checkedAt == null ? this.checkedAt : checkedAt(),
      lastHealthySummary: lastHealthySummary == null
          ? this.lastHealthySummary
          : lastHealthySummary(),
      lastHealthyEndpoint: lastHealthyEndpoint == null
          ? this.lastHealthyEndpoint
          : lastHealthyEndpoint(),
      lastHealthyStatusCode: lastHealthyStatusCode == null
          ? this.lastHealthyStatusCode
          : lastHealthyStatusCode(),
      lastHealthyCheckedAt: lastHealthyCheckedAt == null
          ? this.lastHealthyCheckedAt
          : lastHealthyCheckedAt(),
      pendingTaskCount: pendingTaskCount ?? this.pendingTaskCount,
      failedTaskCount: failedTaskCount ?? this.failedTaskCount,
      conflictTaskCount: conflictTaskCount ?? this.conflictTaskCount,
      lastRunSummary:
          lastRunSummary == null ? this.lastRunSummary : lastRunSummary(),
    );
  }
}
