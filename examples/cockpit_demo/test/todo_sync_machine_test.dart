import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/model/todo_priority.dart';
import 'package:cockpit_demo/src/model/todo_sync_conflict.dart';
import 'package:cockpit_demo/src/model/todo_task.dart';
import 'package:cockpit_demo/src/network/todo_sync_contract.dart';
import 'package:cockpit_demo/src/network/todo_sync_gateway.dart';
import 'package:cockpit_demo/src/app/todo_sync_machine.dart';

void main() {
  test('sync machine classifies success, retryable failure, and conflict',
      () async {
    final pendingTask = _buildTask(id: 'task-success', title: 'Ship notes');
    final retryTask = _buildTask(id: 'task-retry', title: 'Retry notes');
    final conflictTask =
        _buildTask(id: 'task-conflict', title: 'Conflict notes');
    final machine = TodoSyncMachine(
      gateway: _FakeTodoSyncGateway(
        result: TodoSyncBatchResult(
          succeededTaskIds: const <String>['task-success'],
          retryableFailures: const <TodoSyncRetryableFailure>[
            TodoSyncRetryableFailure(
              taskId: 'task-retry',
              summary: 'Relay timed out.',
            ),
          ],
          conflicts: const <TodoSyncConflictEntry>[
            TodoSyncConflictEntry(
              taskId: 'task-conflict',
              conflict: TodoSyncConflict(
                type: TodoSyncConflictType.concurrentEdit,
                summary: 'Remote notes changed while local title changed.',
                localFields: <String>['title'],
                remoteFields: <String>['notes'],
              ),
            ),
          ],
        ),
      ),
      clock: () => DateTime.utc(2026, 4, 12, 9),
    );

    final outcome = await machine.sync(
      tasks: <TodoTask>[pendingTask, retryTask, conflictTask],
    );

    expect(outcome.succeededTaskIds, <String>['task-success']);
    expect(outcome.retryableFailureTaskIds, <String>['task-retry']);
    expect(outcome.conflicts.single.taskId, conflictTask.id);
  });
}

final class _FakeTodoSyncGateway implements TodoSyncGatewayClient {
  _FakeTodoSyncGateway({required this.result});

  final TodoSyncBatchResult result;

  @override
  Future<void> close() async {}

  @override
  Future<TodoSyncProbeResult> probeHealth() {
    throw UnimplementedError();
  }

  @override
  Future<TodoSyncBatchResult> syncTasks(TodoSyncBatchRequest request) async {
    return result;
  }
}

TodoTask _buildTask({required String id, required String title}) {
  final now = DateTime.utc(2026, 4, 12, 9);
  return TodoTask(
    id: id,
    title: title,
    notes: '',
    priority: TodoPriority.medium,
    isCompleted: false,
    displayOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
}
