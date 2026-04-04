import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/app/todo_app_service.dart';
import 'package:cockpit_demo/src/app/todo_sync_state.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/data/todo_repository.dart';
import 'package:cockpit_demo/src/model/todo_filter.dart';
import 'package:cockpit_demo/src/model/todo_priority.dart';
import 'package:cockpit_demo/src/model/todo_settings.dart';
import 'package:cockpit_demo/src/model/todo_tag.dart';
import 'package:cockpit_demo/src/model/todo_task.dart';
import 'package:cockpit_demo/src/network/todo_sync_gateway.dart';

void main() {
  group('TodoAppService', () {
    late CockpitDemoDatabase database;
    late TodoRepository repository;
    late TodoAppService service;

    setUp(() {
      database = CockpitDemoDatabase.inMemory();
      repository = TodoRepository(database);
      service = TodoAppService(repository: repository);
    });

    tearDown(() async {
      service.dispose();
      await database.close();
    });

    test('validates task creation before writing to the repository', () async {
      service.editDraft(title: '   ', notes: 'Ignored');

      final created = await service.submitDraft();

      expect(created, isNull);
      expect(service.editorState.validationMessage, 'Task title is required.');
      expect(service.listState.tasks, isEmpty);
    });

    test('supports delete with undo and refreshes the active list', () async {
      await repository.createTask(title: 'Review bundle artifacts');
      await service.loadTasks();

      final taskId = service.listState.tasks.single.id;
      await service.deleteTask(taskId);

      expect(service.listState.tasks, isEmpty);
      expect(service.listState.canUndoDelete, isTrue);

      final restored = await service.undoDelete();

      expect(restored, isTrue);
      expect(service.listState.tasks, hasLength(1));
      expect(service.listState.tasks.single.title, 'Review bundle artifacts');
      expect(service.listState.canUndoDelete, isFalse);
    });

    test('updates filtered list state after applying a new filter', () async {
      await repository.createTask(
        title: 'Review runtime diagnostics',
        priority: TodoPriority.high,
      );
      await repository.createTask(
        title: 'Ship settings screen',
        priority: TodoPriority.medium,
      );

      await service.loadTasks();
      await service.updateFilter(
        const TodoFilter(
          query: 'review',
          priorities: <TodoPriority>{TodoPriority.high},
        ),
      );

      expect(service.listState.filter.query, 'review');
      expect(service.listState.tasks, hasLength(1));
      expect(
        service.listState.tasks.single.title,
        'Review runtime diagnostics',
      );
    });

    test('creates tags and filters the list by selected tag ids', () async {
      final backendTag = await service.createTag(name: 'Backend');
      await repository.createTask(
        title: 'Verify relay tracing',
        tagIds: <String>[backendTag.id],
      );
      await repository.createTask(title: 'Polish release notes');

      await service.loadTasks(
        TodoFilter(tagIds: <String>{backendTag.id}),
      );

      expect(
        service.availableTags.map((tag) => tag.name).toList(growable: false),
        contains('Backend'),
      );
      expect(service.listState.tasks, hasLength(1));
      expect(service.listState.tasks.single.title, 'Verify relay tracing');
    });

    test('persists settings mutations through the repository', () async {
      await service.loadSettings();

      const updatedSettings = TodoSettings(
        themePreference: TodoThemePreference.dark,
        sortMode: TodoSortMode.dueDate,
        showCompletedInInbox: false,
        compactMode: true,
      );

      await service.updateSettings(updatedSettings);

      expect(service.settingsState.settings, updatedSettings);
      expect(await repository.readSettings(), updatedSettings);
    });

    test(
      'reorders the current list and persists the new manual order',
      () async {
        await repository.createTask(title: 'First task');
        await repository.createTask(title: 'Second task');
        await repository.createTask(title: 'Third task');

        await service.loadTasks();
        await service.reorderTasks(oldIndex: 2, newIndex: 0);

        expect(
          service.listState.tasks
              .map((task) => task.title)
              .toList(growable: false),
          <String>['Third task', 'First task', 'Second task'],
        );
        expect(
          (await repository.fetchTasks(
            const TodoFilter.inbox(),
          ))
              .map((task) => task.title)
              .toList(growable: false),
          <String>['Third task', 'First task', 'Second task'],
        );
      },
    );

    test('updates the priority of multiple tasks in a single batch', () async {
      final first = await repository.createTask(
        title: 'Prepare release notes',
        priority: TodoPriority.low,
      );
      final second = await repository.createTask(
        title: 'Review modal behavior',
        priority: TodoPriority.medium,
      );
      final third = await repository.createTask(
        title: 'Preserve baseline coverage',
        priority: TodoPriority.high,
      );

      await service.loadTasks();
      final updated = await service.updateTasksPriority(
        taskIds: <String>[first.id, second.id],
        priority: TodoPriority.urgent,
      );

      expect(updated, isTrue);
      final refreshed = await repository.fetchTasks(const TodoFilter.inbox());
      final prioritiesById = <String, TodoPriority>{
        for (final task in refreshed) task.id: task.priority,
      };
      expect(prioritiesById[first.id], TodoPriority.urgent);
      expect(prioritiesById[second.id], TodoPriority.urgent);
      expect(prioritiesById[third.id], TodoPriority.high);
    });

    test('updates the due date of multiple tasks in a single batch', () async {
      final first = await repository.createTask(title: 'First scheduled task');
      final second =
          await repository.createTask(title: 'Second scheduled task');
      final third = await repository.createTask(title: 'Unchanged task');
      final tomorrow = DateTime.utc(2026, 4, 6, 17);

      await service.loadTasks();
      final updated = await service.updateTasksDueDate(
        taskIds: <String>[first.id, second.id],
        dueAt: tomorrow,
      );

      expect(updated, isTrue);
      final refreshed = await repository.fetchTasks(const TodoFilter.inbox());
      final dueDatesById = <String, DateTime?>{
        for (final task in refreshed) task.id: task.dueAt?.toUtc(),
      };
      expect(dueDatesById[first.id], tomorrow);
      expect(dueDatesById[second.id], tomorrow);
      expect(dueDatesById[third.id], isNull);
    });

    test('updates the tags of multiple tasks in a single batch', () async {
      final backendTag = await repository.createTag(name: 'Backend');
      final designTag = await repository.createTag(name: 'Design');
      final first = await repository.createTask(
        title: 'Coordinate release notes',
        tagIds: <String>[backendTag.id],
      );
      final second = await repository.createTask(title: 'Align launch brief');
      final third = await repository.createTask(title: 'Keep existing task');

      await service.loadTasks();
      final updated = await service.updateTasksTags(
        taskIds: <String>[first.id, second.id],
        tagIds: <String>[backendTag.id, designTag.id],
      );

      expect(updated, isTrue);
      final refreshed = await repository.fetchTasks(const TodoFilter.inbox());
      final tagsById = <String, List<String>>{
        for (final task in refreshed)
          task.id: task.tags.map((tag) => tag.name).toList(growable: false),
      };
      expect(tagsById[first.id], <String>['Backend', 'Design']);
      expect(tagsById[second.id], <String>['Backend', 'Design']);
      expect(tagsById[third.id], isEmpty);
    });

    test('creates a follow-up task while carrying selected fields', () async {
      final backendTag = await repository.createTag(name: 'Backend');
      final source = await repository.createTask(
        title: 'Verify relay tracing',
        notes: 'Preserve the context for the next step.',
        priority: TodoPriority.high,
        tagIds: <String>[backendTag.id],
      );
      final followUpDueAt = DateTime.utc(2026, 4, 7, 17);

      final followUp = await service.createFollowUpTask(
        sourceTaskId: source.id,
        title: 'Verify relay tracing follow-up',
        carryNotes: true,
        carryTags: true,
        dueAt: followUpDueAt,
      );

      expect(followUp.title, 'Verify relay tracing follow-up');
      expect(followUp.notes, 'Preserve the context for the next step.');
      expect(followUp.priority, TodoPriority.high);
      expect(followUp.dueAt?.toUtc(), followUpDueAt);
      expect(
        followUp.tags.map((tag) => tag.name).toList(growable: false),
        <String>['Backend'],
      );
    });

    test('deletes multiple tasks with one undo batch', () async {
      final first = await repository.createTask(title: 'First batch task');
      final second = await repository.createTask(title: 'Second batch task');
      await repository.createTask(title: 'Keep visible');

      await service.loadTasks();
      final deleted = await service.deleteTasks(<String>[first.id, second.id]);

      expect(deleted, isTrue);
      expect(
        service.listState.tasks
            .map((task) => task.title)
            .toList(growable: false),
        <String>['Keep visible'],
      );
      expect(
        service.listState.pendingUndoTasks.map((task) => task.id).toList(
              growable: false,
            ),
        <String>[first.id, second.id],
      );

      final restored = await service.undoDelete();

      expect(restored, isTrue);
      expect(service.listState.pendingUndoTasks, isEmpty);
      expect(service.listState.tasks, hasLength(3));
    });

    test('captures repository failures as recoverable state', () async {
      final failingService = TodoAppService(
        repository: _FailingTodoRepository(),
      );
      addTearDown(failingService.dispose);

      await failingService.loadTasks();

      expect(failingService.listState.errorMessage, 'Simulated fetch failure');
      expect(failingService.listState.tasks, isEmpty);
      expect(failingService.listState.isLoading, isFalse);
    });

    test(
      'runs a sync health check and stores a delivery-friendly status',
      () async {
        service = TodoAppService(
          repository: repository,
          syncGateway: _FakeTodoSyncGateway(),
        );

        await service.runSyncHealthCheck();

        expect(service.syncState.status, TodoSyncStatus.healthy);
        expect(service.syncState.headline, 'Relay ready');
        expect(service.syncState.statusCode, 200);
        expect(service.syncState.endpoint, contains('/sync/health'));
        expect(service.syncState.detail, contains('pending writes 0'));
      },
    );

    test(
      'preserves the last successful sync check when a later relay check fails',
      () async {
        service = TodoAppService(
          repository: repository,
          syncGateway: _SequenceTodoSyncGateway(
            results: <Object>[
              TodoSyncProbeResult(
                endpoint: Uri.parse('http://127.0.0.1:47331/sync/health'),
                checkedAt: DateTime.utc(2026, 3, 21, 4),
                statusCode: 200,
                responseBody: const <String, Object?>{
                  'status': 'ready',
                  'summary': 'Local relay healthy · pending writes 0',
                },
                summary: 'Local relay healthy · pending writes 0',
              ),
              StateError('Simulated relay outage'),
            ],
          ),
        );

        await service.runSyncHealthCheck();
        await service.runSyncHealthCheck();

        expect(service.syncState.status, TodoSyncStatus.failed);
        expect(service.syncState.headline, 'Relay unavailable');
        expect(
          service.syncState.lastHealthySummary,
          'Local relay healthy · pending writes 0',
        );
        expect(
          service.syncState.lastHealthyEndpoint,
          'http://127.0.0.1:47331/sync/health',
        );
        expect(service.syncState.lastHealthyStatusCode, 200);
        expect(
          service.syncState.lastHealthyCheckedAt,
          DateTime.utc(2026, 3, 21, 4),
        );
      },
    );

    test('can reset sync relay state back to idle after previous checks',
        () async {
      service = TodoAppService(
        repository: repository,
        syncGateway: _FakeTodoSyncGateway(),
      );

      await service.runSyncHealthCheck();

      expect(service.syncState.status, TodoSyncStatus.healthy);
      expect(service.syncState.hasSuccessfulCheck, isTrue);

      service.resetSyncRelayState();

      expect(service.syncState.status, TodoSyncStatus.idle);
      expect(service.syncState.headline, 'Sync relay idle');
      expect(
        service.syncState.detail,
        'Run a relay check to capture request and response evidence.',
      );
      expect(service.syncState.endpoint, isNull);
      expect(service.syncState.statusCode, isNull);
      expect(service.syncState.checkedAt, isNull);
      expect(service.syncState.hasSuccessfulCheck, isFalse);
      expect(service.syncState.lastHealthySummary, isNull);
      expect(service.syncState.lastHealthyEndpoint, isNull);
      expect(service.syncState.lastHealthyStatusCode, isNull);
      expect(service.syncState.lastHealthyCheckedAt, isNull);
    });
  });
}

final class _FakeTodoSyncGateway implements TodoSyncGatewayClient {
  @override
  Future<void> close() async {}

  @override
  Future<TodoSyncProbeResult> probeHealth() async {
    return TodoSyncProbeResult(
      endpoint: Uri.parse('http://127.0.0.1:47331/sync/health'),
      checkedAt: DateTime.utc(2026, 3, 21, 4),
      statusCode: 200,
      responseBody: const <String, Object?>{
        'status': 'ready',
        'summary': 'Local relay healthy · pending writes 0',
      },
      summary: 'Local relay healthy · pending writes 0',
    );
  }
}

final class _SequenceTodoSyncGateway implements TodoSyncGatewayClient {
  _SequenceTodoSyncGateway({required List<Object> results})
      : _results = List<Object>.from(results);

  final List<Object> _results;

  @override
  Future<void> close() async {}

  @override
  Future<TodoSyncProbeResult> probeHealth() async {
    final next = _results.removeAt(0);
    if (next is TodoSyncProbeResult) {
      return next;
    }
    if (next is Error) {
      throw next;
    }
    throw next;
  }
}

final class _FailingTodoRepository implements TodoRepositoryClient {
  @override
  Future<TodoTag> createTag({required String name, String? colorHex}) {
    throw UnimplementedError();
  }

  @override
  Future<TodoTask> createTask({
    required String title,
    String notes = '',
    TodoPriority priority = TodoPriority.medium,
    DateTime? dueAt,
    List<String> tagIds = const <String>[],
  }) {
    throw StateError('Simulated create failure');
  }

  @override
  Future<TodoTask> deleteTask(String taskId) {
    throw StateError('Simulated delete failure');
  }

  @override
  Future<List<TodoTask>> deleteTasks(List<String> taskIds) {
    throw StateError('Simulated delete failure');
  }

  @override
  Future<List<TodoTask>> fetchTasks(TodoFilter filter) {
    throw StateError('Simulated fetch failure');
  }

  @override
  Future<List<TodoTag>> fetchTags() async => const <TodoTag>[];

  @override
  Future<TodoTask?> getTask(String taskId) async => null;

  @override
  Future<void> reorderTasks(List<String> orderedTaskIds) async {}

  @override
  Future<TodoSettings> readSettings() async => TodoSettings.defaults;

  @override
  Future<TodoTask> restoreTask(String taskId) {
    throw StateError('Simulated restore failure');
  }

  @override
  Future<void> restoreTasks(List<String> taskIds) {
    throw StateError('Simulated restore failure');
  }

  @override
  Future<void> saveSettings(TodoSettings settings) async {}

  @override
  Future<TodoTask> setTaskCompleted({
    required String taskId,
    required bool isCompleted,
  }) {
    throw StateError('Simulated completion failure');
  }

  @override
  Future<void> setTasksCompleted({
    required List<String> taskIds,
    required bool isCompleted,
  }) {
    throw StateError('Simulated completion failure');
  }

  @override
  Future<TodoTask> updateTask({
    required String taskId,
    required String title,
    String notes = '',
    TodoPriority priority = TodoPriority.medium,
    DateTime? dueAt,
    List<String> tagIds = const <String>[],
  }) {
    throw StateError('Simulated update failure');
  }

  @override
  Future<List<TodoTask>> updateTasksPriority({
    required List<String> taskIds,
    required TodoPriority priority,
  }) {
    throw StateError('Simulated update failure');
  }

  @override
  Future<List<TodoTask>> updateTasksDueDate({
    required List<String> taskIds,
    required DateTime? dueAt,
  }) {
    throw StateError('Simulated update failure');
  }

  @override
  Future<List<TodoTask>> updateTasksTags({
    required List<String> taskIds,
    required List<String> tagIds,
  }) {
    throw StateError('Simulated update failure');
  }

  @override
  Future<TodoTask> createFollowUpTask({
    required String sourceTaskId,
    required String title,
    required bool carryNotes,
    required bool carryTags,
    DateTime? dueAt,
  }) {
    throw StateError('Simulated create failure');
  }
}
