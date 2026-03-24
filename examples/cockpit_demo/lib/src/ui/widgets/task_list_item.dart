import 'package:flutter/material.dart';

import '../../model/todo_priority.dart';
import '../../model/todo_task.dart';
import '../theme/orbit_todo_theme.dart';

final class TaskListItem extends StatelessWidget {
  const TaskListItem({
    required this.task,
    required this.compactMode,
    required this.selectionMode,
    required this.isSelected,
    required this.isHighlighted,
    required this.onTap,
    required this.onLongPress,
    required this.onDoubleTap,
    required this.onToggleCompleted,
    super.key,
    this.dragHandle,
  });

  final TodoTask task;
  final bool compactMode;
  final bool selectionMode;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDoubleTap;
  final ValueChanged<bool> onToggleCompleted;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rowHeight = compactMode ? 112.0 : 132.0;
    final contentVerticalPadding = compactMode ? 12.0 : 15.0;
    final toggleTopPadding = compactMode ? 16.0 : 20.0;
    final metadataTopPadding = compactMode ? 16.0 : 20.0;
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.45,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: rowHeight),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.secondaryContainer.withAlphaFraction(0.42)
            : isHighlighted
                ? colorScheme.primaryContainer.withAlphaFraction(0.48)
                : Colors.transparent,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withAlphaFraction(0.86),
          ),
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                color: isSelected || isHighlighted
                    ? colorScheme.primary
                    : Colors.transparent,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 0, 4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: toggleTopPadding),
                  child: Semantics(
                    label:
                        '${task.isCompleted ? 'Reopen' : 'Complete'} task ${task.title}',
                    checked: task.isCompleted,
                    child: Checkbox(
                      key: ValueKey<String>('task-toggle-${task.id}'),
                      value: task.isCompleted,
                      onChanged: (value) => onToggleCompleted(value ?? false),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: selectionMode
                        ? 'Toggle selection for task ${task.title}'
                        : 'Open task ${task.title}',
                    button: true,
                    child: InkWell(
                      key: ValueKey<String>('task-open-${task.id}'),
                      onTap: onTap,
                      onLongPress: onLongPress,
                      onDoubleTap: onDoubleTap,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: contentVerticalPadding,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                _PriorityLabel(priority: task.priority),
                                if (task.dueAt != null)
                                  _InlineMeta(
                                    label: 'Due ${_formatDate(task.dueAt!)}',
                                    color: colorScheme.tertiary,
                                  ),
                                if (task.isCompleted)
                                  _InlineMeta(
                                    label: 'Completed',
                                    color: colorScheme.primary,
                                  ),
                                if (isSelected)
                                  _InlineMeta(
                                    label: 'Selected',
                                    color: colorScheme.secondary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.isCompleted
                                    ? colorScheme.onSurfaceVariant
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                                height: 0.98,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              task.notes.isNotEmpty
                                  ? task.notes
                                  : task.isCompleted
                                      ? 'Finished and ready to archive.'
                                      : 'Open for notes, due date, and next actions.',
                              maxLines: compactMode ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: subtitleStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: EdgeInsets.only(
                    top: metadataTopPadding,
                    bottom: contentVerticalPadding,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        task.dueAt == null ? 'Open' : _formatDate(task.dueAt!),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: selectionMode
                              ? colorScheme.secondary
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      if (dragHandle != null) ...<Widget>[
                        SizedBox(height: compactMode ? 26 : 34),
                        dragHandle!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day';
  }
}

final class _PriorityLabel extends StatelessWidget {
  const _PriorityLabel({required this.priority});

  final TodoPriority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color) = switch (priority) {
      TodoPriority.low => ('LOW', theme.colorScheme.secondary),
      TodoPriority.medium => ('MEDIUM', theme.colorScheme.tertiary),
      TodoPriority.high => ('HIGH', theme.colorScheme.primary),
      TodoPriority.urgent => ('URGENT', theme.colorScheme.error),
    };

    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    );
  }
}

final class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedColor = color ?? theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 8, height: 1, color: resolvedColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: resolvedColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
