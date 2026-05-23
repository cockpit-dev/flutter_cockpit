import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/data/todo_repository.dart';
import 'package:cockpit_demo/src/model/todo_filter.dart';
import 'package:cockpit_demo/src/model/todo_priority.dart';
import 'package:cockpit_demo/src/model/todo_settings.dart';
import 'package:cockpit_demo/src/model/todo_sync_conflict.dart';
import 'package:cockpit_demo/src/model/todo_tag.dart';
import 'package:cockpit_demo/src/model/todo_task_sync_status.dart';

void main() {
  group('TodoRepository', () {
    late CockpitDemoDatabase database;
    late TodoRepository repository;

    setUp(() {
      database = CockpitDemoDatabase.inMemory();
      repository = TodoRepository(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('creates and updates persisted tasks with tags', () async {
      final workTag = await repository.createTag(
        name: 'Work',
        colorHex: '#FF0F766E',
      );
      final dueAt = DateTime.utc(2026, 3, 21, 10);

      final created = await repository.createTask(
        title: 'Review MCP workflow',
        notes: 'Check delivery bundle fields',
        priority: TodoPriority.high,
        dueAt: dueAt,
        tagIds: <String>[workTag.id],
      );

      expect(created.title, 'Review MCP workflow');
      expect(created.notes, 'Check delivery bundle fields');
      expect(created.priority, TodoPriority.high);
      expect(created.dueAt, dueAt);
      expect(created.tags, <TodoTag>[workTag]);
      expect(created.isCompleted, isFalse);
      expect(created.deletedAt, isNull);

      final updated = await repository.updateTask(
        taskId: created.id,
        title: 'Review remote MCP workflow',
        notes: 'Check delivery and validation bundle fields',
        priority: TodoPriority.urgent,
        dueAt: dueAt.add(const Duration(days: 1)),
        tagIds: const <String>[],
      );

      expect(updated.title, 'Review remote MCP workflow');
      expect(updated.notes, 'Check delivery and validation bundle fields');
      expect(updated.priority, TodoPriority.urgent);
      expect(updated.tags, isEmpty);
      expect(updated.updatedAt.isAfter(created.updatedAt), isTrue);
    });

    test('completes, uncompletes, soft-deletes, and restores tasks', () async {
      final created = await repository.createTask(
        title: 'Stabilize simulator validation',
      );

      final completed = await repository.setTaskCompleted(
        taskId: created.id,
        isCompleted: true,
      );
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      final reopened = await repository.setTaskCompleted(
        taskId: created.id,
        isCompleted: false,
      );
      expect(reopened.isCompleted, isFalse);
      expect(reopened.completedAt, isNull);

      final deleted = await repository.deleteTask(created.id);
      expect(deleted.deletedAt, isNotNull);

      final activeTasks = await repository.fetchTasks(const TodoFilter.inbox());
      expect(activeTasks.map((task) => task.id), isNot(contains(created.id)));

      final restored = await repository.restoreTask(created.id);
      expect(restored.deletedAt, isNull);

      final restoredTasks = await repository.fetchTasks(
        const TodoFilter.inbox(),
      );
      expect(restoredTasks.map((task) => task.id), contains(created.id));
    });

    test(
      'searches and filters tasks by query, completion, and priority',
      () async {
        await repository.createTask(
          title: 'Review diagnostics snapshot',
          priority: TodoPriority.high,
        );
        final completedTask = await repository.createTask(
          title: 'Ship simulator capture proof',
          priority: TodoPriority.urgent,
        );
        await repository.setTaskCompleted(
          taskId: completedTask.id,
          isCompleted: true,
        );
        await repository.createTask(
          title: 'Draft todo settings screen',
          priority: TodoPriority.medium,
        );

        final matchingInboxTasks = await repository.fetchTasks(
          const TodoFilter(
            query: 'review',
            completionFilter: TodoCompletionFilter.active,
            priorities: <TodoPriority>{TodoPriority.high},
          ),
        );
        expect(matchingInboxTasks, hasLength(1));
        expect(matchingInboxTasks.single.title, 'Review diagnostics snapshot');

        final completedTasks = await repository.fetchTasks(
          const TodoFilter.completed(),
        );
        expect(completedTasks, hasLength(1));
        expect(completedTasks.single.title, 'Ship simulator capture proof');
      },
    );

    test('reorders tasks by updating persisted display order', () async {
      final first = await repository.createTask(title: 'First pass');
      final second = await repository.createTask(title: 'Second pass');
      final third = await repository.createTask(title: 'Third pass');

      await repository.reorderTasks(<String>[third.id, first.id, second.id]);

      final reordered = await repository.fetchTasks(const TodoFilter.inbox());
      expect(reordered.map((task) => task.id).toList(growable: false), <String>[
        third.id,
        first.id,
        second.id,
      ]);
    });

    test('persists user settings with stable defaults', () async {
      expect(await repository.readSettings(), TodoSettings.defaults);

      const settings = TodoSettings(
        themePreference: TodoThemePreference.dark,
        sortMode: TodoSortMode.dueDate,
        showCompletedInInbox: false,
        compactMode: true,
      );

      await repository.saveSettings(settings);

      expect(await repository.readSettings(), settings);
    });

    test('persists sync metadata and filters conflicted tasks', () async {
      final created = await repository.createTask(title: 'Resolve launch copy');

      await repository.applySyncResolution(
        taskId: created.id,
        syncStatus: TodoTaskSyncStatus.conflicted,
        localRevision: 2,
        remoteRevision: 4,
        conflict: const TodoSyncConflict(
          type: TodoSyncConflictType.concurrentEdit,
          summary: 'Remote notes changed while local title changed.',
          localFields: <String>['title'],
          remoteFields: <String>['notes'],
        ),
      );

      final conflicted = await repository.fetchTasks(
        const TodoFilter(
          syncStatuses: <TodoTaskSyncStatus>{TodoTaskSyncStatus.conflicted},
        ),
      );

      expect(conflicted, hasLength(1));
      expect(conflicted.single.id, created.id);
      expect(conflicted.single.syncStatus, TodoTaskSyncStatus.conflicted);
      expect(
        conflicted.single.syncConflict?.type,
        TodoSyncConflictType.concurrentEdit,
      );
      expect(conflicted.single.localRevision, 2);
      expect(conflicted.single.remoteRevision, 4);
    });
  });
}
