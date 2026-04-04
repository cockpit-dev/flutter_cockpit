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
    this.pendingUndoTasks = const <TodoTask>[],
    this.focusedTaskId,
  });

  final List<TodoTask> tasks;
  final TodoFilter filter;
  final bool isLoading;
  final String? errorMessage;
  final List<TodoTask> pendingUndoTasks;
  final String? focusedTaskId;

  TodoTask? get pendingUndoTask =>
      pendingUndoTasks.length == 1 ? pendingUndoTasks.single : null;
  int get pendingUndoCount => pendingUndoTasks.length;
  bool get canUndoDelete => pendingUndoTasks.isNotEmpty;

  TodoListState copyWith({
    List<TodoTask>? tasks,
    TodoFilter? filter,
    bool? isLoading,
    ValueGetter<String?>? errorMessage,
    List<TodoTask>? pendingUndoTasks,
    ValueGetter<String?>? focusedTaskId,
  }) {
    return TodoListState(
      tasks: tasks ?? this.tasks,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == null ? this.errorMessage : errorMessage(),
      pendingUndoTasks: pendingUndoTasks ?? this.pendingUndoTasks,
      focusedTaskId:
          focusedTaskId == null ? this.focusedTaskId : focusedTaskId(),
    );
  }
}
