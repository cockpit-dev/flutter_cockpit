import 'package:flutter/foundation.dart';

import '../model/todo_filter.dart';
import '../model/todo_task.dart';

@immutable
final class TodoListState {
  const TodoListState({
    this.tasks = const <TodoTask>[],
    this.filter = const TodoFilter.inbox(),
    this.isLoading = false,
    this.errorMessage,
    this.pendingUndoTask,
    this.focusedTaskId,
  });

  final List<TodoTask> tasks;
  final TodoFilter filter;
  final bool isLoading;
  final String? errorMessage;
  final TodoTask? pendingUndoTask;
  final String? focusedTaskId;

  bool get canUndoDelete => pendingUndoTask != null;

  TodoListState copyWith({
    List<TodoTask>? tasks,
    TodoFilter? filter,
    bool? isLoading,
    ValueGetter<String?>? errorMessage,
    ValueGetter<TodoTask?>? pendingUndoTask,
    ValueGetter<String?>? focusedTaskId,
  }) {
    return TodoListState(
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
      pendingUndoTask:
          pendingUndoTask == null ? this.pendingUndoTask : pendingUndoTask(),
      focusedTaskId:
          focusedTaskId == null ? this.focusedTaskId : focusedTaskId(),
    );
  }
}
