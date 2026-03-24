import 'package:flutter/foundation.dart';

import 'todo_priority.dart';
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
    this.dueAt,
    this.completedAt,
    this.deletedAt,
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
        Object.hashAll(tags),
      );
}
