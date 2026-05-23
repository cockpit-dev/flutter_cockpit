import '../model/todo_task.dart';
import '../network/todo_sync_contract.dart';
import '../network/todo_sync_gateway.dart';

final class TodoSyncMachine {
  TodoSyncMachine({
    required TodoSyncGatewayClient gateway,
    DateTime Function()? clock,
  }) : _gateway = gateway,
       _clock = clock ?? DateTime.now;

  final TodoSyncGatewayClient _gateway;
  final DateTime Function() _clock;

  Future<TodoSyncRunOutcome> sync({required List<TodoTask> tasks}) async {
    final result = await _gateway.syncTasks(
      TodoSyncBatchRequest.fromTasks(
        tasks: tasks,
        triggeredAt: _clock().toUtc(),
      ),
    );
    return TodoSyncRunOutcome.fromGatewayResult(result);
  }
}

final class TodoSyncRunOutcome {
  const TodoSyncRunOutcome({
    required this.succeededTaskIds,
    required this.retryableFailures,
    required this.conflicts,
  });

  final List<String> succeededTaskIds;
  final List<TodoSyncRetryableFailure> retryableFailures;
  final List<TodoSyncConflictEntry> conflicts;

  List<String> get retryableFailureTaskIds => retryableFailures
      .map((failure) => failure.taskId)
      .toList(growable: false);

  bool get hasFailures => retryableFailures.isNotEmpty;
  bool get hasConflicts => conflicts.isNotEmpty;
  int get pendingTaskCount => retryableFailures.length + conflicts.length;

  factory TodoSyncRunOutcome.fromGatewayResult(TodoSyncBatchResult result) {
    return TodoSyncRunOutcome(
      succeededTaskIds: List<String>.unmodifiable(result.succeededTaskIds),
      retryableFailures: List<TodoSyncRetryableFailure>.unmodifiable(
        result.retryableFailures,
      ),
      conflicts: List<TodoSyncConflictEntry>.unmodifiable(result.conflicts),
    );
  }
}
