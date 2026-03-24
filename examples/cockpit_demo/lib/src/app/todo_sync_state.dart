import 'package:flutter/foundation.dart';

enum TodoSyncStatus { idle, checking, healthy, failed }

@immutable
final class TodoSyncState {
  const TodoSyncState({
    this.status = TodoSyncStatus.idle,
    this.headline = 'Sync relay idle',
    this.detail = 'Run a relay check to capture request and response evidence.',
    this.endpoint,
    this.statusCode,
    this.checkedAt,
  });

  final TodoSyncStatus status;
  final String headline;
  final String detail;
  final String? endpoint;
  final int? statusCode;
  final DateTime? checkedAt;

  bool get isChecking => status == TodoSyncStatus.checking;

  TodoSyncState copyWith({
    TodoSyncStatus? status,
    String? headline,
    String? detail,
    ValueGetter<String?>? endpoint,
    ValueGetter<int?>? statusCode,
    ValueGetter<DateTime?>? checkedAt,
  }) {
    return TodoSyncState(
      status: status ?? this.status,
      headline: headline ?? this.headline,
      detail: detail ?? this.detail,
      endpoint: endpoint == null ? this.endpoint : endpoint(),
      statusCode: statusCode == null ? this.statusCode : statusCode(),
      checkedAt: checkedAt == null ? this.checkedAt : checkedAt(),
    );
  }
}
