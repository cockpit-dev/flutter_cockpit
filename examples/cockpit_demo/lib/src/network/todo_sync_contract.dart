import '../model/todo_sync_conflict.dart';
import '../model/todo_task.dart';

final class TodoSyncBatchRequest {
  const TodoSyncBatchRequest({
    required this.tasks,
    required this.triggeredAt,
  });

  final List<TodoTask> tasks;
  final DateTime triggeredAt;

  factory TodoSyncBatchRequest.fromTasks({
    required List<TodoTask> tasks,
    required DateTime triggeredAt,
  }) {
    return TodoSyncBatchRequest(
      tasks: List<TodoTask>.unmodifiable(tasks),
      triggeredAt: triggeredAt,
    );
  }
}

final class TodoSyncRetryableFailure {
  const TodoSyncRetryableFailure({
    required this.taskId,
    required this.summary,
  });

  final String taskId;
  final String summary;
}

final class TodoSyncConflictEntry {
  const TodoSyncConflictEntry({
    required this.taskId,
    required this.conflict,
  });

  final String taskId;
  final TodoSyncConflict conflict;
}

final class TodoSyncBatchResult {
  const TodoSyncBatchResult({
    this.succeededTaskIds = const <String>[],
    this.retryableFailures = const <TodoSyncRetryableFailure>[],
    this.conflicts = const <TodoSyncConflictEntry>[],
  });

  final List<String> succeededTaskIds;
  final List<TodoSyncRetryableFailure> retryableFailures;
  final List<TodoSyncConflictEntry> conflicts;
}
