import 'package:flutter/foundation.dart';

import '../model/todo_priority.dart';

@immutable
final class TodoEditorState {
  const TodoEditorState({
    this.title = '',
    this.notes = '',
    this.priority = TodoPriority.medium,
    this.dueAt,
    this.selectedTagIds = const <String>[],
    this.isSaving = false,
    this.validationMessage,
  });

  static const TodoEditorState empty = TodoEditorState();

  final String title;
  final String notes;
  final TodoPriority priority;
  final DateTime? dueAt;
  final List<String> selectedTagIds;
  final bool isSaving;
  final String? validationMessage;

  TodoEditorState copyWith({
    String? title,
    String? notes,
    TodoPriority? priority,
    ValueGetter<DateTime?>? dueAt,
    List<String>? selectedTagIds,
    bool? isSaving,
    ValueGetter<String?>? validationMessage,
  }) {
    return TodoEditorState(
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      dueAt: dueAt == null ? this.dueAt : dueAt(),
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      isSaving: isSaving ?? this.isSaving,
      validationMessage: validationMessage == null
          ? this.validationMessage
          : validationMessage(),
    );
  }
}
