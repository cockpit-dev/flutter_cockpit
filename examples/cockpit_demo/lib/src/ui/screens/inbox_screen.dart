import 'package:flutter/material.dart';
import '../../app/todo_app_service.dart';
import '../../model/todo_filter.dart';
import '../../model/todo_task.dart';
import 'todo_collection_screen.dart';

final class InboxScreen extends StatelessWidget {
  const InboxScreen({
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
      routeName: '/inbox',
      title: 'Inbox',
      baseFilter: const TodoFilter.inbox(),
      navigationIndex: 0,
      service: service,
      onOpenEditor: onOpenEditor,
      onOpenTask: onOpenTask,
      onOpenSettings: onOpenSettings,
      onNavigateToIndex: onNavigateToIndex,
    );
  }
}
