import 'package:flutter/material.dart';

import '../../app/todo_app_service.dart';
import '../../data/todo_repository.dart';
import '../../model/todo_sync_conflict.dart';
import '../../model/todo_task.dart';
import '../widgets/editorial_section.dart';

final class SyncConflictScreen extends StatefulWidget {
  const SyncConflictScreen({
    required this.service,
    required this.repository,
    required this.task,
    super.key,
  });

  final TodoAppService service;
  final TodoRepositoryClient repository;
  final TodoTask task;

  @override
  State<SyncConflictScreen> createState() => _SyncConflictScreenState();
}

final class _SyncConflictScreenState extends State<SyncConflictScreen> {
  bool _isResolving = false;

  Future<void> _resolve(TodoConflictResolution resolution) async {
    setState(() {
      _isResolving = true;
    });
    await widget.service.resolveConflict(
      taskId: widget.task.id,
      resolution: resolution,
    );
    final refreshed = await widget.repository.getTask(widget.task.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (resolution) {
          TodoConflictResolution.keepLocal => 'Conflict resolved locally.',
          TodoConflictResolution.keepRemote => 'Remote version restored.',
          TodoConflictResolution.mergeFields => 'Conflict merged for retry.',
        }),
      ),
    );
    Navigator.of(context).pop(refreshed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final conflict = widget.task.syncConflict;
    return Scaffold(
      appBar: AppBar(title: const Text('Resolve conflict')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 80),
        children: <Widget>[
          EditorialSection(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SYNC CONFLICT',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(widget.task.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  conflict?.summary ?? 'No conflict details are available.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (conflict != null) ...<Widget>[
            const SizedBox(height: 24),
            EditorialSection(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Local fields', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    conflict.localFields.join(', '),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text('Remote fields', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    conflict.remoteFields.join(', '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isResolving
                ? null
                : () => _resolve(TodoConflictResolution.keepLocal),
            child: const Text('Keep local'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isResolving
                ? null
                : () => _resolve(TodoConflictResolution.keepRemote),
            child: const Text('Keep remote'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isResolving
                ? null
                : () => _resolve(TodoConflictResolution.mergeFields),
            child: const Text('Merge fields'),
          ),
        ],
      ),
    );
  }
}
