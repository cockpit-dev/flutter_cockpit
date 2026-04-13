import 'package:flutter/foundation.dart';

import 'todo_priority.dart';
import 'todo_sync_conflict.dart';
import 'todo_task_sync_status.dart';
import 'todo_tag.dart';

@immutable
final class TodoTask {
  const TodoTask({
    required this.id,
    required this.title,
    required this.notes,
    required this.priority,
    required this.isCompleted,
    required this.displayOrder,
    required this.createdAt,
    required this.updatedAt,
    this.syncStatus = TodoTaskSyncStatus.idle,
    this.localRevision = 0,
    this.remoteRevision = 0,
    this.dueAt,
    this.completedAt,
    this.deletedAt,
    this.lastSyncedAt,
    this.lastSyncFailure,
    this.pendingChanges = const <String>[],
    this.syncConflict,
    this.tags = const <TodoTag>[],
  });

  final String id;
  final String title;
  final String notes;
  final TodoPriority priority;
  final DateTime? dueAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime? deletedAt;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TodoTaskSyncStatus syncStatus;
  final int localRevision;
  final int remoteRevision;
  final DateTime? lastSyncedAt;
  final String? lastSyncFailure;
  final List<String> pendingChanges;
  final TodoSyncConflict? syncConflict;
  final List<TodoTag> tags;

  List<String> get tagIds => tags.map((tag) => tag.id).toList(growable: false);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TodoTask &&
            other.id == id &&
            other.title == title &&
            other.notes == notes &&
            other.priority == priority &&
            other.dueAt == dueAt &&
            other.isCompleted == isCompleted &&
            other.completedAt == completedAt &&
            other.deletedAt == deletedAt &&
            other.displayOrder == displayOrder &&
            other.createdAt == createdAt &&
            other.updatedAt == updatedAt &&
            other.syncStatus == syncStatus &&
            other.localRevision == localRevision &&
            other.remoteRevision == remoteRevision &&
            other.lastSyncedAt == lastSyncedAt &&
            other.lastSyncFailure == lastSyncFailure &&
            listEquals(other.pendingChanges, pendingChanges) &&
            other.syncConflict == syncConflict &&
            listEquals(other.tags, tags);
  }

  @override
  int get hashCode => Object.hash(
        id,
        title,
        notes,
        priority,
        dueAt,
        isCompleted,
        completedAt,
        deletedAt,
        displayOrder,
        createdAt,
        updatedAt,
        syncStatus,
        localRevision,
        remoteRevision,
        lastSyncedAt,
        lastSyncFailure,
        Object.hashAll(pendingChanges),
        syncConflict,
        Object.hashAll(tags),
      );
}
