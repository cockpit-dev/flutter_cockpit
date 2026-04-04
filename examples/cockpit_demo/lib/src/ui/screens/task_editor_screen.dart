import 'package:flutter/material.dart';

import '../../app/todo_app_service.dart';
import '../../model/todo_priority.dart';
import '../../model/todo_task.dart';
import '../theme/orbit_todo_theme.dart';
import '../widgets/editorial_section.dart';

final class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({required this.service, this.task, super.key});

  final TodoAppService service;
  final TodoTask? task;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

final class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _notesController;
  late TodoPriority _priority;
  DateTime? _dueAt;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _notesController = TextEditingController(text: task?.notes ?? '');
    _notesController.addListener(_handleNotesChanged);
    _priority = task?.priority ?? TodoPriority.medium;
    _dueAt = task?.dueAt;
  }

  @override
  void dispose() {
    _notesController.removeListener(_handleNotesChanged);
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleNotesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    widget.service.editDraft(
      title: _titleController.text,
      notes: _notesController.text,
      priority: _priority,
      dueAt: () => _dueAt,
    );
    final savedTask = await widget.service.submitDraft(
      existingTaskId: widget.task?.id,
    );
    if (savedTask == null || !mounted) {
      return;
    }

    Navigator.of(context).pop(savedTask.id);
  }

  void _selectDuePreset(String preset) {
    final today = DateTime.now();
    setState(() {
      _dueAt = switch (preset) {
        'none' => null,
        'today' => DateTime(today.year, today.month, today.day, 17),
        'tomorrow' => DateTime(today.year, today.month, today.day + 1, 17),
        _ => _dueAt,
      };
    });
  }

  void _clearNotes() {
    _notesController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final editorState = widget.service.editorState;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.task == null ? 'Create task' : 'Edit task'),
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
                        widget.task == null ? 'TASK' : 'EDIT',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.task == null
                            ? 'Capture the next item.'
                            : 'Adjust scope, timing, or notes.',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Keep title, urgency, and due date explicit so the task remains easy to scan in both manual use and AI validation.',
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
                        'TASK',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0.95,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('Task', style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Write the shortest title that still survives search and handoff later.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: const ValueKey<String>('task-title-input'),
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Task title',
                          errorText: editorState.validationMessage ==
                                  'Task title is required.'
                              ? editorState.validationMessage
                              : null,
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        key: const ValueKey<String>('task-notes-input'),
                        controller: _notesController,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText:
                              'Add context, handoff details, or validation notes.',
                        ),
                      ),
                      if (_notesController.text.trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const ValueKey<String>(
                              'task-clear-notes-button',
                            ),
                            onPressed: _clearNotes,
                            icon: const Icon(Icons.clear_rounded),
                            label: const Text('Clear notes'),
                          ),
                        ),
                      ],
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
                        'SCHEDULING',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0.95,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Priority and due date',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Use urgency for ordering and a due date only when the task is truly time-bound.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text('Priority', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: TodoPriority.values
                            .map(
                              (priority) => ChoiceChip(
                                key: ValueKey<String>(
                                  'task-priority-${priority.name}',
                                ),
                                selected: _priority == priority,
                                label: Text(priority.name.toUpperCase()),
                                onSelected: (_) {
                                  setState(() {
                                    _priority = priority;
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                      const SizedBox(height: 18),
                      Text('Due date', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          ChoiceChip(
                            key: const ValueKey<String>('task-due-none'),
                            selected: _dueAt == null,
                            label: const Text('No date'),
                            onSelected: (_) => _selectDuePreset('none'),
                          ),
                          ChoiceChip(
                            key: const ValueKey<String>('task-due-today'),
                            selected: _dueAt != null &&
                                _dueAt!.difference(DateTime.now()).inDays == 0,
                            label: const Text('Today'),
                            onSelected: (_) => _selectDuePreset('today'),
                          ),
                          ChoiceChip(
                            key: const ValueKey<String>('task-due-tomorrow'),
                            selected: _dueAt != null &&
                                _dueAt!.difference(DateTime.now()).inDays == 1,
                            label: const Text('Tomorrow'),
                            onSelected: (_) => _selectDuePreset('tomorrow'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (editorState.validationMessage != null &&
                    editorState.validationMessage !=
                        'Task title is required.') ...<Widget>[
                  const SizedBox(height: 24),
                  EditorialSection(
                    leadingAccentColor: colorScheme.error,
                    backgroundColor:
                        colorScheme.errorContainer.withAlphaFraction(
                      0.82,
                    ),
                    padding: const EdgeInsets.fromLTRB(0, 18, 0, 18),
                    child: Text(
                      editorState.validationMessage!,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FilledButton.icon(
                key: const ValueKey<String>('task-save-button'),
                onPressed: editorState.isSaving ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(widget.task == null ? 'Save task' : 'Save changes'),
              ),
            ),
          ),
        );
      },
    );
  }
}
