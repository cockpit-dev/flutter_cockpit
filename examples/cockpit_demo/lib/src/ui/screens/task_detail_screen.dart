import 'package:flutter/material.dart';

import '../../app/todo_app_service.dart';
import '../../data/todo_repository.dart';
import '../../model/todo_task.dart';
import '../theme/orbit_todo_theme.dart';
import '../widgets/editorial_section.dart';

final class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    required this.service,
    required this.repository,
    required this.task,
    required this.onEdit,
    super.key,
  });

  final TodoAppService service;
  final TodoRepositoryClient repository;
  final TodoTask task;
  final Future<TodoTask?> Function(TodoTask task) onEdit;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

final class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late TodoTask _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _toggleCompleted(bool value) async {
    await widget.service.setTaskCompleted(taskId: _task.id, isCompleted: value);
    final refreshed = await widget.repository.getTask(_task.id);
    if (refreshed != null && mounted) {
      setState(() {
        _task = refreshed;
      });
    }
  }

  Future<void> _editTask() async {
    final refreshed = await widget.onEdit(_task);
    if (!mounted || refreshed == null) {
      return;
    }
    setState(() {
      _task = refreshed;
    });
  }

  Future<void> _deleteTask() async {
    await widget.service.deleteTask(_task.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task detail'),
        actions: <Widget>[
          IconButton(
            key: const ValueKey<String>('detail-edit-button'),
            tooltip: 'Edit task',
            onPressed: _editTask,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            key: const ValueKey<String>('detail-delete-button'),
            tooltip: 'Delete task',
            onPressed: _deleteTask,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
          children: <Widget>[
            EditorialSection(
              padding: const EdgeInsets.fromLTRB(0, 26, 0, 26),
              backgroundColor: theme.editorialMutedSurfaceColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'DETAIL',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _task.title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: <Widget>[
                      _DetailChip(
                        label: 'Priority ${_task.priority.name}',
                        icon: Icons.flag_rounded,
                      ),
                      if (_task.dueAt != null)
                        _DetailChip(
                          label:
                              'Due ${_task.dueAt!.month}/${_task.dueAt!.day}',
                          icon: Icons.event_available_rounded,
                        ),
                      _DetailChip(
                        label: _task.isCompleted ? 'Completed' : 'In progress',
                        icon: _task.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.timelapse_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            EditorialSection(
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'NOTES',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.95,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Notes', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  Text(
                    _task.notes.isEmpty ? 'No notes added yet.' : _task.notes,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            EditorialSection(
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'STATUS',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.95,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('Status', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    key: const ValueKey<String>('detail-complete-toggle'),
                    value: _task.isCompleted,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Completed'),
                    subtitle: Text(
                      _task.isCompleted
                          ? 'This task is archived as finished work.'
                          : 'Mark this once the outcome is stable and reviewable.',
                    ),
                    onChanged: (value) => _toggleCompleted(value ?? false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outlineVariant.withAlphaFraction(0.82),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
