import 'package:flutter/foundation.dart';

import 'todo_priority.dart';

enum TodoCompletionFilter { active, completed, all }

@immutable
final class TodoFilter {
  const TodoFilter({
    this.query = '',
    this.completionFilter = TodoCompletionFilter.active,
    this.priorities = const <TodoPriority>{},
    this.tagIds = const <String>{},
    this.includeDeleted = false,
    this.onlyDueToday = false,
  });

  const TodoFilter.inbox()
      : query = '',
        completionFilter = TodoCompletionFilter.active,
        priorities = const <TodoPriority>{},
        tagIds = const <String>{},
        includeDeleted = false,
        onlyDueToday = false;

  const TodoFilter.completed()
      : query = '',
        completionFilter = TodoCompletionFilter.completed,
        priorities = const <TodoPriority>{},
        tagIds = const <String>{},
        includeDeleted = false,
        onlyDueToday = false;

  final String query;
  final TodoCompletionFilter completionFilter;
  final Set<TodoPriority> priorities;
  final Set<String> tagIds;
  final bool includeDeleted;
  final bool onlyDueToday;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TodoFilter &&
            other.query == query &&
            other.completionFilter == completionFilter &&
            setEquals(other.priorities, priorities) &&
            setEquals(other.tagIds, tagIds) &&
            other.includeDeleted == includeDeleted &&
            other.onlyDueToday == onlyDueToday;
  }

  @override
  int get hashCode => Object.hash(
        query,
        completionFilter,
        Object.hashAll(priorities),
        Object.hashAll(tagIds),
        includeDeleted,
        onlyDueToday,
      );
}
