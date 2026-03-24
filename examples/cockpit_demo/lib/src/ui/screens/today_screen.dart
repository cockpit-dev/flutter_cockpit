import 'package:flutter/material.dart';
import '../../app/todo_app_service.dart';
import '../../model/todo_filter.dart';
import '../../model/todo_task.dart';
import 'todo_collection_screen.dart';

final class TodayScreen extends StatelessWidget {
  const TodayScreen({
    required this.service,
    required this.onOpenEditor,
    required this.onOpenTask,
    required this.onOpenSettings,
    required this.onNavigateToIndex,
    super.key,
  });

  final TodoAppService service;
  final Future<String?> Function() onOpenEditor;
  final Future<void> Function(TodoTask task) onOpenTask;
  final Future<void> Function() onOpenSettings;
  final void Function(int index) onNavigateToIndex;

  @override
  Widget build(BuildContext context) {
    return TodoCollectionScreen(
      routeName: '/today',
      title: 'Today',
      baseFilter: const TodoFilter(
        onlyDueToday: true,
        completionFilter: TodoCompletionFilter.active,
      ),
      navigationIndex: 1,
      service: service,
      onOpenEditor: onOpenEditor,
      onOpenTask: onOpenTask,
      onOpenSettings: onOpenSettings,
      onNavigateToIndex: onNavigateToIndex,
    );
  }
}
