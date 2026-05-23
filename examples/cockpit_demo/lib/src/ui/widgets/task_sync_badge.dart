import 'package:flutter/material.dart';

import '../../model/todo_task_sync_status.dart';

final class TaskSyncBadge extends StatelessWidget {
  const TaskSyncBadge({required this.status, super.key});

  final TodoTaskSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (label, foreground, background) = switch (status) {
      TodoTaskSyncStatus.pending => (
        'Pending sync',
        colorScheme.tertiary,
        colorScheme.tertiaryContainer,
      ),
      TodoTaskSyncStatus.failed => (
        'Sync failed',
        colorScheme.error,
        colorScheme.errorContainer,
      ),
      TodoTaskSyncStatus.conflicted => (
        'Conflict',
        colorScheme.primary,
        colorScheme.primaryContainer,
      ),
      TodoTaskSyncStatus.syncing => (
        'Syncing',
        colorScheme.secondary,
        colorScheme.secondaryContainer,
      ),
      TodoTaskSyncStatus.synced => (
        'Synced',
        colorScheme.primary,
        colorScheme.primaryContainer,
      ),
      TodoTaskSyncStatus.idle => (
        'Idle',
        colorScheme.onSurfaceVariant,
        colorScheme.surfaceContainerHighest,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(color: background),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
