import 'package:flutter/material.dart';

import '../../app/todo_app_service.dart';
import '../../data/todo_repository.dart';
import '../../model/todo_task_sync_status.dart';
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

  Future<void> _createFollowUp() async {
    final createdTask = await showModalBottomSheet<TodoTask>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _CreateFollowUpSheet(service: widget.service, sourceTask: _task),
    );
    if (createdTask == null || !mounted) {
      return;
    }
    await Navigator.of(
      context,
    ).pushReplacementNamed('/detail', arguments: createdTask);
  }

  Future<void> _resolveConflict() async {
    final refreshed = await Navigator.of(
      context,
    ).pushNamed('/sync-conflict', arguments: _task);
    if (!mounted) {
      return;
    }
    final latest = refreshed is TodoTask
        ? refreshed
        : await widget.repository.getTask(_task.id);
    if (latest == null) {
      return;
    }
    setState(() {
      _task = latest;
    });
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
            tooltip: 'Create follow-up',
            onPressed: _createFollowUp,
            icon: const Icon(Icons.copy_all_rounded),
          ),
          IconButton(
            tooltip: 'Edit task',
            onPressed: _editTask,
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
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
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 26),
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
                      if (_task.syncStatus != TodoTaskSyncStatus.idle)
                        _DetailChip(
                          label: 'Sync ${_task.syncStatus.name}',
                          icon: Icons.sync_rounded,
                        ),
                    ],
                  ),
                  if (_task.tags.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _task.tags
                          .map(
                            (tag) => _DetailChip(
                              label: tag.name,
                              icon: Icons.sell_rounded,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
            if (_task.syncConflict != null) ...<Widget>[
              const SizedBox(height: 24),
              EditorialSection(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'SYNC',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.95,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Conflict requires review',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _task.syncConflict!.summary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: _resolveConflict,
                      child: const Text('Resolve conflict'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            EditorialSection(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
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
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
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

final class _CreateFollowUpSheet extends StatefulWidget {
  const _CreateFollowUpSheet({required this.service, required this.sourceTask});

  final TodoAppService service;
  final TodoTask sourceTask;

  @override
  State<_CreateFollowUpSheet> createState() => _CreateFollowUpSheetState();
}

final class _CreateFollowUpSheetState extends State<_CreateFollowUpSheet> {
  late final TextEditingController _titleController;
  bool _carryNotes = true;
  bool _carryTags = true;
  DateTime? _dueAt;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: '${widget.sourceTask.title} follow-up',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _selectDuePreset(String preset) {
    final today = DateTime.now();
    setState(() {
      _dueAt = switch (preset) {
        'none' => null,
        'today' => DateTime(today.year, today.month, today.day, 17),
        'tomorrow' => DateTime(today.year, today.month, today.day + 1, 17),
        'nextWeek' => DateTime(today.year, today.month, today.day + 7, 17),
        _ => _dueAt,
      };
    });
  }

  Future<void> _submit() async {
    final normalizedTitle = _titleController.text.trim();
    if (normalizedTitle.isEmpty) {
      setState(() {
        _errorMessage = 'Follow-up title is required.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final createdTask = await widget.service.createFollowUpTask(
        sourceTaskId: widget.sourceTask.id,
        title: normalizedTitle,
        carryNotes: _carryNotes,
        carryTags: _carryTags,
        dueAt: _dueAt,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(createdTask);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Follow-up task',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Spin the current task into the next executable step without losing the context that still matters.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _titleController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Follow-up title',
                          errorText: _errorMessage,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Carry notes'),
                        subtitle: const Text(
                          'Preserve implementation context and handoff details.',
                        ),
                        value: _carryNotes,
                        onChanged: (value) {
                          setState(() {
                            _carryNotes = value;
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Carry tags'),
                        subtitle: const Text(
                          'Keep domain ownership such as backend or design.',
                        ),
                        value: _carryTags,
                        onChanged: (value) {
                          setState(() {
                            _carryTags = value;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Text('Due date', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          ChoiceChip(
                            selected: _dueAt == null,
                            label: const Text('No date'),
                            onSelected: (_) => _selectDuePreset('none'),
                          ),
                          ChoiceChip(
                            selected:
                                _dueAt != null &&
                                _dueAt!.difference(DateTime.now()).inDays == 0,
                            label: const Text('Today'),
                            onSelected: (_) => _selectDuePreset('today'),
                          ),
                          ChoiceChip(
                            selected:
                                _dueAt != null &&
                                _dueAt!.difference(DateTime.now()).inDays == 1,
                            label: const Text('Tomorrow'),
                            onSelected: (_) => _selectDuePreset('tomorrow'),
                          ),
                          ChoiceChip(
                            selected:
                                _dueAt != null &&
                                _dueAt!.difference(DateTime.now()).inDays >= 6,
                            label: const Text('Next week'),
                            onSelected: (_) => _selectDuePreset('nextWeek'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _submit,
                  icon: const Icon(Icons.copy_all_rounded),
                  label: Text(_isSaving ? 'Creating…' : 'Create follow-up'),
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
