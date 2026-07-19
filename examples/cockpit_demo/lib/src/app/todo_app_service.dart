import 'package:flutter/foundation.dart';

import '../data/todo_repository.dart';
import '../model/todo_filter.dart';
import '../model/todo_priority.dart';
import '../model/todo_settings.dart';
import '../model/todo_sync_conflict.dart';
import '../model/todo_tag.dart';
import '../model/todo_task.dart';
import '../model/todo_task_sync_status.dart';
import '../network/todo_sync_gateway.dart';
import 'todo_editor_state.dart';
import 'todo_list_state.dart';
import 'todo_settings_state.dart';
import 'todo_sync_machine.dart';
import 'todo_sync_state.dart';

final class TodoAppService extends ChangeNotifier {
  TodoAppService({
    required TodoRepositoryClient repository,
    TodoSyncGatewayClient? syncGateway,
  }) : _repository = repository,
       _syncGateway = syncGateway;

  final TodoRepositoryClient _repository;
  final TodoSyncGatewayClient? _syncGateway;
  bool _isDisposed = false;

  TodoEditorState _editorState = TodoEditorState.empty;
  TodoListState _listState = const TodoListState();
  TodoSettingsState _settingsState = const TodoSettingsState();
  TodoSyncState _syncState = const TodoSyncState();
  List<TodoTag> _availableTags = const <TodoTag>[];
  bool _isLoadingTags = false;
  String? _tagsErrorMessage;

  TodoEditorState get editorState => _editorState;
  TodoListState get listState => _listState;
  TodoSettingsState get settingsState => _settingsState;
  TodoSyncState get syncState => _syncState;
  List<TodoTag> get availableTags => _availableTags;
  bool get isLoadingTags => _isLoadingTags;
  String? get tagsErrorMessage => _tagsErrorMessage;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notifyListenersIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void editDraft({
    String? title,
    String? notes,
    TodoPriority? priority,
    ValueGetter<DateTime?>? dueAt,
    List<String>? selectedTagIds,
  }) {
    _editorState = _editorState.copyWith(
      title: title,
      notes: notes,
      priority: priority,
      dueAt: dueAt,
      selectedTagIds: selectedTagIds,
      validationMessage: () => null,
    );
    _notifyListenersIfActive();
  }

  Future<void> loadTasks([TodoFilter? filter, String? focusedTaskId]) async {
    final nextFilter = filter ?? _listState.filter;
    _listState = _listState.copyWith(
      filter: nextFilter,
      isLoading: true,
      errorMessage: () => null,
    );
    _notifyListenersIfActive();

    try {
      final tasks = _sortTasks(
        await _repository.fetchTasks(nextFilter),
        _settingsState.settings.sortMode,
      );
      if (_isDisposed) {
        return;
      }
      _listState = _listState.copyWith(
        tasks: tasks,
        filter: nextFilter,
        isLoading: false,
        errorMessage: () => null,
        focusedTaskId: () {
          final candidateFocusId = focusedTaskId ?? _listState.focusedTaskId;
          if (candidateFocusId == null) {
            return null;
          }
          return tasks.any((task) => task.id == candidateFocusId)
              ? candidateFocusId
              : null;
        },
      );
      _syncState = _syncState.copyWith(
        pendingTaskCount: _countTasksWithSyncStatus(
          tasks,
          const <TodoTaskSyncStatus>{
            TodoTaskSyncStatus.pending,
            TodoTaskSyncStatus.failed,
          },
        ),
        failedTaskCount: _countTasksWithSyncStatus(
          tasks,
          const <TodoTaskSyncStatus>{TodoTaskSyncStatus.failed},
        ),
        conflictTaskCount: _countTasksWithSyncStatus(
          tasks,
          const <TodoTaskSyncStatus>{TodoTaskSyncStatus.conflicted},
        ),
      );
    } on Object catch (error) {
      if (_isDisposed) {
        return;
      }
      _listState = _listState.copyWith(
        tasks: const <TodoTask>[],
        filter: nextFilter,
        isLoading: false,
        errorMessage: () => _errorMessage(error),
        focusedTaskId: () => null,
      );
    }
    _notifyListenersIfActive();
  }

  Future<void> updateFilter(TodoFilter filter) {
    return loadTasks(filter);
  }

  Future<void> loadTags() async {
    _isLoadingTags = true;
    _tagsErrorMessage = null;
    _notifyListenersIfActive();

    try {
      final tags = await _repository.fetchTags();
      if (_isDisposed) {
        return;
      }
      _availableTags = List<TodoTag>.unmodifiable(tags);
      _tagsErrorMessage = null;
    } on Object catch (error) {
      if (_isDisposed) {
        return;
      }
      _tagsErrorMessage = _errorMessage(error);
    } finally {
      if (!_isDisposed) {
        _isLoadingTags = false;
        _notifyListenersIfActive();
      }
    }
  }

  Future<TodoTag> createTag({required String name, String? colorHex}) async {
    final createdTag = await _repository.createTag(
      name: name,
      colorHex: colorHex,
    );
    if (_isDisposed) {
      return createdTag;
    }
    await loadTags();
    return createdTag;
  }

  Future<void> setTaskCompleted({
    required String taskId,
    required bool isCompleted,
  }) async {
    await setTasksCompleted(
      taskIds: <String>[taskId],
      isCompleted: isCompleted,
    );
  }

  Future<bool> setTasksCompleted({
    required List<String> taskIds,
    required bool isCompleted,
  }) async {
    final normalizedIds = taskIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return false;
    }
    try {
      await _repository.setTasksCompleted(
        taskIds: normalizedIds,
        isCompleted: isCompleted,
      );
      if (_isDisposed) {
        return false;
      }
      await loadTasks();
      return true;
    } on Object catch (error) {
      if (_isDisposed) {
        return false;
      }
      _listState = _listState.copyWith(
        errorMessage: () => _errorMessage(error),
      );
      _notifyListenersIfActive();
      return false;
    }
  }

  Future<TodoTask?> submitDraft({String? existingTaskId}) async {
    final normalizedTitle = _editorState.title.trim();
    if (normalizedTitle.isEmpty) {
      const validationMessage = 'Task title is required.';
      _editorState = _editorState.copyWith(
        validationMessage: () => validationMessage,
      );
      _notifyListenersIfActive();
      return null;
    }

    _editorState = _editorState.copyWith(
      isSaving: true,
      validationMessage: () => null,
    );
    _notifyListenersIfActive();

    try {
      late final TodoTask savedTask;
      if (existingTaskId == null) {
        savedTask = await _repository.createTask(
          title: normalizedTitle,
          notes: _editorState.notes,
          priority: _editorState.priority,
          dueAt: _editorState.dueAt,
          tagIds: _editorState.selectedTagIds,
        );
      } else {
        savedTask = await _repository.updateTask(
          taskId: existingTaskId,
          title: normalizedTitle,
          notes: _editorState.notes,
          priority: _editorState.priority,
          dueAt: _editorState.dueAt,
          tagIds: _editorState.selectedTagIds,
        );
      }
      if (_isDisposed) {
        return null;
      }
      final queuedTask = await _repository.applySyncResolution(
        taskId: savedTask.id,
        syncStatus: TodoTaskSyncStatus.pending,
        localRevision: savedTask.localRevision + 1,
        remoteRevision: savedTask.remoteRevision,
        pendingChanges: _draftPendingChanges(),
        conflict: null,
        lastSyncFailure: null,
        lastSyncedAt: savedTask.lastSyncedAt,
      );
      _editorState = TodoEditorState.empty;
      await loadTasks(_listState.filter, queuedTask.id);
      return queuedTask;
    } on Object catch (error) {
      if (_isDisposed) {
        return null;
      }
      final message = _errorMessage(error);
      _editorState = _editorState.copyWith(
        isSaving: false,
        validationMessage: () => message,
      );
      _notifyListenersIfActive();
      return null;
    }
  }

  Future<void> deleteTask(String taskId) async {
    await deleteTasks(<String>[taskId]);
  }

  Future<bool> deleteTasks(List<String> taskIds) async {
    final normalizedIds = taskIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return false;
    }
    try {
      final deleted = await _repository.deleteTasks(normalizedIds);
      if (_isDisposed) {
        return false;
      }
      _listState = _listState.copyWith(
        pendingUndoTasks: List<TodoTask>.unmodifiable(deleted),
        errorMessage: () => null,
      );
      _notifyListenersIfActive();
      await loadTasks();
      return true;
    } on Object catch (error) {
      if (_isDisposed) {
        return false;
      }
      _listState = _listState.copyWith(
        errorMessage: () => _errorMessage(error),
      );
      _notifyListenersIfActive();
      return false;
    }
  }

  Future<bool> undoDelete() async {
    final pendingTasks = _listState.pendingUndoTasks;
    if (pendingTasks.isEmpty) {
      return false;
    }

    try {
      await _repository.restoreTasks(
        pendingTasks.map((task) => task.id).toList(growable: false),
      );
      if (_isDisposed) {
        return false;
      }
      _listState = _listState.copyWith(
        pendingUndoTasks: const <TodoTask>[],
        errorMessage: () => null,
      );
      _notifyListenersIfActive();
      await loadTasks();
      return true;
    } on Object catch (error) {
      if (_isDisposed) {
        return false;
      }
      _listState = _listState.copyWith(
        errorMessage: () => _errorMessage(error),
      );
      _notifyListenersIfActive();
      return false;
    }
  }

  Future<bool> updateTasksPriority({
    required List<String> taskIds,
    required TodoPriority priority,
  }) async {
    final normalizedIds = taskIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return false;
    }

    try {
      await _repository.updateTasksPriority(
        taskIds: normalizedIds,
        priority: priority,
      );
      if (_isDisposed) {
        return false;
      }
      await loadTasks();
      return true;
    } on Object catch (error) {
      if (_isDisposed) {
        return false;
      }
      _listState = _listState.copyWith(
        errorMessage: () => _errorMessage(error),
      );
      _notifyListenersIfActive();
      return false;
    }
  }

  Future<bool> updateTasksDueDate({
    required List<String> taskIds,
    required DateTime? dueAt,
  }) async {
    final normalizedIds = taskIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return false;
    }

    try {
      await _repository.updateTasksDueDate(
        taskIds: normalizedIds,
        dueAt: dueAt,
      );
      if (_isDisposed) {
        return false;
      }
      await loadTasks();
      return true;
    } on Object catch (error) {
      if (_isDisposed) {
        return false;
      }
      _listState = _listState.copyWith(
        errorMessage: () => _errorMessage(error),
      );
      _notifyListenersIfActive();
      return false;
    }
  }

  Future<bool> updateTasksTags({
    required List<String> taskIds,
    required List<String> tagIds,
  }) async {
    final normalizedIds = taskIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return false;
    }

    try {
      await _repository.updateTasksTags(taskIds: normalizedIds, tagIds: tagIds);
      if (_isDisposed) {
        return false;
      }
      await loadTasks();
      return true;
    } on Object catch (error) {
      if (_isDisposed) {
        return false;
      }
      _listState = _listState.copyWith(
        errorMessage: () => _errorMessage(error),
      );
      _notifyListenersIfActive();
      return false;
    }
  }

  Future<List<TodoTask>> duplicateTasks({
    required List<String> taskIds,
    required String titlePrefix,
    required bool carryNotes,
    required bool carryDueDate,
    required bool carryTags,
  }) async {
    final normalizedIds = taskIds.toSet().toList(growable: false);
    if (normalizedIds.isEmpty) {
      return const <TodoTask>[];
    }

    try {
      final duplicated = await _repository.duplicateTasks(
        taskIds: normalizedIds,
        titlePrefix: titlePrefix,
        carryNotes: carryNotes,
        carryDueDate: carryDueDate,
        carryTags: carryTags,
      );
      if (_isDisposed) {
        return duplicated;
      }
      final focusedTaskId = duplicated.isEmpty ? null : duplicated.first.id;
      await loadTasks(_listState.filter, focusedTaskId);
      return duplicated;
    } on Object catch (error) {
      if (_isDisposed) {
        return const <TodoTask>[];
      }
      _listState = _listState.copyWith(
        errorMessage: () => _errorMessage(error),
      );
      _notifyListenersIfActive();
      return const <TodoTask>[];
    }
  }

  Future<TodoTask> createFollowUpTask({
    required String sourceTaskId,
    required String title,
    required bool carryNotes,
    required bool carryTags,
    DateTime? dueAt,
  }) async {
    final followUp = await _repository.createFollowUpTask(
      sourceTaskId: sourceTaskId,
      title: title,
      carryNotes: carryNotes,
      carryTags: carryTags,
      dueAt: dueAt,
    );
    if (_isDisposed) {
      return followUp;
    }
    await loadTasks(_listState.filter, followUp.id);
    return followUp;
  }

  Future<void> reorderTasks({
    required int oldIndex,
    required int newIndex,
  }) async {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _listState.tasks.length ||
        newIndex > _listState.tasks.length) {
      return;
    }

    final adjustedNewIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (adjustedNewIndex == oldIndex) {
      return;
    }

    final reorderedTasks = _listState.tasks.toList(growable: true);
    final movedTask = reorderedTasks.removeAt(oldIndex);
    reorderedTasks.insert(adjustedNewIndex, movedTask);
    _listState = _listState.copyWith(
      tasks: List<TodoTask>.unmodifiable(reorderedTasks),
      errorMessage: () => null,
    );
    _notifyListenersIfActive();

    try {
      await _repository.reorderTasks(
        reorderedTasks.map((task) => task.id).toList(growable: false),
      );
      if (_isDisposed) {
        return;
      }
      await loadTasks();
    } on Object catch (error) {
      if (_isDisposed) {
        return;
      }
      _listState = _listState.copyWith(
        errorMessage: () => _errorMessage(error),
      );
      _notifyListenersIfActive();
    }
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _repository.readSettings();
      if (_isDisposed) {
        return;
      }
      _settingsState = _settingsState.copyWith(
        settings: settings,
        isSaving: false,
        errorMessage: () => null,
      );
    } on Object catch (error) {
      if (_isDisposed) {
        return;
      }
      _settingsState = _settingsState.copyWith(
        isSaving: false,
        errorMessage: () => _errorMessage(error),
      );
    }
    _notifyListenersIfActive();
  }

  Future<void> updateSettings(TodoSettings settings) async {
    _settingsState = _settingsState.copyWith(
      isSaving: true,
      errorMessage: () => null,
    );
    _notifyListenersIfActive();

    try {
      await _repository.saveSettings(settings);
      if (_isDisposed) {
        return;
      }
      _settingsState = _settingsState.copyWith(
        settings: settings,
        isSaving: false,
        errorMessage: () => null,
      );
      await loadTasks();
    } on Object catch (error) {
      if (_isDisposed) {
        return;
      }
      _settingsState = _settingsState.copyWith(
        isSaving: false,
        errorMessage: () => _errorMessage(error),
      );
    }
    _notifyListenersIfActive();
  }

  void dismissFocusedTask() {
    if (_listState.focusedTaskId == null) {
      return;
    }
    _listState = _listState.copyWith(focusedTaskId: () => null);
    _notifyListenersIfActive();
  }

  Future<TodoTask?> editTaskAndQueueSync({
    required String taskId,
    required String title,
  }) async {
    final existing = await _repository.getTask(taskId);
    if (existing == null) {
      return null;
    }
    final updated = await _repository.updateTask(
      taskId: taskId,
      title: title,
      notes: existing.notes,
      priority: existing.priority,
      dueAt: existing.dueAt,
      tagIds: existing.tagIds,
    );
    final queued = await _repository.applySyncResolution(
      taskId: updated.id,
      syncStatus: TodoTaskSyncStatus.pending,
      localRevision: updated.localRevision + 1,
      remoteRevision: updated.remoteRevision,
      pendingChanges: const <String>['title'],
      conflict: null,
      lastSyncFailure: null,
      lastSyncedAt: updated.lastSyncedAt,
    );
    await loadTasks(_listState.filter, queued.id);
    return queued;
  }

  Future<void> runSyncNow() async {
    final syncGateway = _syncGateway;
    if (syncGateway == null) {
      _syncState = _syncState.copyWith(
        status: TodoSyncStatus.failed,
        headline: 'Relay unavailable',
        detail: 'No sync relay is attached to this app instance.',
        lastRunSummary: () => 'No sync relay is attached to this app instance.',
      );
      _notifyListenersIfActive();
      return;
    }

    final queuedTasks = await _repository.fetchTasks(
      const TodoFilter(
        completionFilter: TodoCompletionFilter.all,
        syncStatuses: <TodoTaskSyncStatus>{
          TodoTaskSyncStatus.pending,
          TodoTaskSyncStatus.failed,
          TodoTaskSyncStatus.conflicted,
        },
      ),
    );
    if (queuedTasks.isEmpty) {
      _syncState = _syncState.copyWith(
        status: TodoSyncStatus.synced,
        headline: 'Sync complete',
        detail: 'No queued task changes are waiting to sync.',
        pendingTaskCount: 0,
        failedTaskCount: 0,
        conflictTaskCount: 0,
        lastRunSummary: () => 'No queued task changes are waiting to sync.',
      );
      _notifyListenersIfActive();
      return;
    }

    _syncState = _syncState.copyWith(
      status: TodoSyncStatus.syncing,
      headline: 'Syncing tasks…',
      detail: 'Pushing queued local edits through the sync boundary.',
      pendingTaskCount: queuedTasks.length,
    );
    _notifyListenersIfActive();

    final outcome = await TodoSyncMachine(
      gateway: syncGateway,
    ).sync(tasks: queuedTasks);
    final queuedById = <String, TodoTask>{
      for (final task in queuedTasks) task.id: task,
    };

    for (final taskId in outcome.succeededTaskIds) {
      final task = queuedById[taskId];
      if (task == null) {
        continue;
      }
      await _repository.applySyncResolution(
        taskId: task.id,
        syncStatus: TodoTaskSyncStatus.synced,
        localRevision: task.localRevision,
        remoteRevision: task.localRevision,
        pendingChanges: const <String>[],
        conflict: null,
        lastSyncFailure: null,
        lastSyncedAt: DateTime.now().toUtc(),
      );
    }

    for (final failure in outcome.retryableFailures) {
      final task = queuedById[failure.taskId];
      if (task == null) {
        continue;
      }
      await _repository.applySyncResolution(
        taskId: task.id,
        syncStatus: TodoTaskSyncStatus.failed,
        localRevision: task.localRevision,
        remoteRevision: task.remoteRevision,
        pendingChanges: task.pendingChanges,
        conflict: null,
        lastSyncFailure: failure.summary,
        lastSyncedAt: task.lastSyncedAt,
      );
    }

    for (final conflictEntry in outcome.conflicts) {
      final task = queuedById[conflictEntry.taskId];
      if (task == null) {
        continue;
      }
      await _repository.applySyncResolution(
        taskId: task.id,
        syncStatus: TodoTaskSyncStatus.conflicted,
        localRevision: task.localRevision,
        remoteRevision: task.remoteRevision + 1,
        pendingChanges: task.pendingChanges,
        conflict: conflictEntry.conflict,
        lastSyncFailure: null,
        lastSyncedAt: task.lastSyncedAt,
      );
    }

    await loadTasks(_listState.filter);
    final nextStatus = outcome.hasConflicts
        ? TodoSyncStatus.conflicted
        : outcome.hasFailures
        ? TodoSyncStatus.failed
        : TodoSyncStatus.synced;
    _syncState = _syncState.copyWith(
      status: nextStatus,
      headline: switch (nextStatus) {
        TodoSyncStatus.conflicted => 'Conflicts detected',
        TodoSyncStatus.failed => 'Sync needs retry',
        _ => 'Sync complete',
      },
      detail: switch (nextStatus) {
        TodoSyncStatus.conflicted =>
          'Resolve conflicts before running sync again.',
        TodoSyncStatus.failed => 'Retry failed sync items after investigating.',
        _ => 'All queued task changes synced successfully.',
      },
      pendingTaskCount: outcome.pendingTaskCount,
      failedTaskCount: outcome.retryableFailures.length,
      conflictTaskCount: outcome.conflicts.length,
      lastRunSummary: () => switch (nextStatus) {
        TodoSyncStatus.conflicted =>
          'Conflicts detected for ${outcome.conflicts.length} tasks.',
        TodoSyncStatus.failed =>
          'Retry required for ${outcome.retryableFailures.length} tasks.',
        _ => 'All queued task changes synced successfully.',
      },
    );
    _notifyListenersIfActive();
  }

  Future<void> resolveConflict({
    required String taskId,
    required TodoConflictResolution resolution,
  }) async {
    final task = await _repository.getTask(taskId);
    if (task == null) {
      return;
    }

    switch (resolution) {
      case TodoConflictResolution.keepLocal:
        await _repository.applySyncResolution(
          taskId: task.id,
          syncStatus: TodoTaskSyncStatus.pending,
          localRevision: task.localRevision + 1,
          remoteRevision: task.remoteRevision,
          pendingChanges: const <String>['resolved_keep_local'],
          conflict: null,
          lastSyncFailure: null,
          lastSyncedAt: task.lastSyncedAt,
        );
      case TodoConflictResolution.mergeFields:
        await _repository.applySyncResolution(
          taskId: task.id,
          syncStatus: TodoTaskSyncStatus.pending,
          localRevision: task.localRevision + 1,
          remoteRevision: task.remoteRevision,
          pendingChanges: const <String>['merge_fields'],
          conflict: null,
          lastSyncFailure: null,
          lastSyncedAt: task.lastSyncedAt,
        );
      case TodoConflictResolution.keepRemote:
        await _repository.applySyncResolution(
          taskId: task.id,
          syncStatus: TodoTaskSyncStatus.synced,
          localRevision: task.localRevision,
          remoteRevision: task.remoteRevision,
          pendingChanges: const <String>[],
          conflict: null,
          lastSyncFailure: null,
          lastSyncedAt: DateTime.now().toUtc(),
        );
    }
    await loadTasks(_listState.filter, task.id);
  }

  Future<void> runSyncHealthCheck() async {
    final syncGateway = _syncGateway;
    if (syncGateway == null) {
      _syncState = _syncState.copyWith(
        status: TodoSyncStatus.failed,
        headline: 'Relay unavailable',
        detail: 'No sync relay is attached to this app instance.',
        endpoint: () => null,
        statusCode: () => null,
        checkedAt: () => DateTime.now().toUtc(),
      );
      _notifyListenersIfActive();
      return;
    }

    _syncState = _syncState.copyWith(
      status: TodoSyncStatus.checking,
      headline: 'Checking relay…',
      detail: 'Sending a health probe through the local sync boundary.',
      checkedAt: () => DateTime.now().toUtc(),
    );
    _notifyListenersIfActive();

    try {
      final result = await syncGateway.probeHealth();
      if (_isDisposed) {
        return;
      }
      final isHealthy = result.statusCode >= 200 && result.statusCode < 300;
      _syncState = _syncState.copyWith(
        status: isHealthy ? TodoSyncStatus.healthy : TodoSyncStatus.failed,
        headline: isHealthy ? 'Relay ready' : 'Relay degraded',
        detail: result.summary,
        endpoint: () => result.endpoint.toString(),
        statusCode: () => result.statusCode,
        checkedAt: () => result.checkedAt,
        lastHealthySummary: isHealthy ? () => result.summary : null,
        lastHealthyEndpoint: isHealthy
            ? () => result.endpoint.toString()
            : null,
        lastHealthyStatusCode: isHealthy ? () => result.statusCode : null,
        lastHealthyCheckedAt: isHealthy ? () => result.checkedAt : null,
      );
    } on Object catch (error) {
      if (_isDisposed) {
        return;
      }
      _syncState = _syncState.copyWith(
        status: TodoSyncStatus.failed,
        headline: 'Relay unavailable',
        detail: _errorMessage(error),
        endpoint: () => null,
        statusCode: () => null,
        checkedAt: () => DateTime.now().toUtc(),
      );
    }
    _notifyListenersIfActive();
  }

  void setSimulateRelayFailure(bool value) {
    if (_syncState.simulateFailure == value) {
      return;
    }
    _syncState = _syncState.copyWith(simulateFailure: value);
    _notifyListenersIfActive();
  }

  void resetSyncRelayState() {
    _syncState = TodoSyncState(simulateFailure: _syncState.simulateFailure);
    _notifyListenersIfActive();
  }

  int _countTasksWithSyncStatus(
    List<TodoTask> tasks,
    Set<TodoTaskSyncStatus> statuses,
  ) {
    return tasks.where((task) => statuses.contains(task.syncStatus)).length;
  }

  List<String> _draftPendingChanges() {
    final changes = <String>[
      'title',
      if (_editorState.notes.trim().isNotEmpty) 'notes',
      if (_editorState.dueAt != null) 'dueAt',
      if (_editorState.selectedTagIds.isNotEmpty) 'tags',
    ];
    return changes.toSet().toList(growable: false);
  }

  List<TodoTask> _sortTasks(List<TodoTask> tasks, TodoSortMode sortMode) {
    final sorted = tasks.toList(growable: true);
    switch (sortMode) {
      case TodoSortMode.manual:
        sorted.sort(
          (left, right) => left.displayOrder.compareTo(right.displayOrder),
        );
        return List<TodoTask>.unmodifiable(sorted);
      case TodoSortMode.dueDate:
        sorted.sort((left, right) {
          final leftDue = left.dueAt;
          final rightDue = right.dueAt;
          if (leftDue == null && rightDue == null) {
            return left.displayOrder.compareTo(right.displayOrder);
          }
          if (leftDue == null) {
            return 1;
          }
          if (rightDue == null) {
            return -1;
          }
          return leftDue.compareTo(rightDue);
        });
        return List<TodoTask>.unmodifiable(sorted);
      case TodoSortMode.priority:
        sorted.sort(
          (left, right) =>
              right.priority.storageValue.compareTo(left.priority.storageValue),
        );
        return List<TodoTask>.unmodifiable(sorted);
      case TodoSortMode.updatedAt:
        sorted.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
        return List<TodoTask>.unmodifiable(sorted);
    }
  }

  String _errorMessage(Object error) {
    final message = error.toString();
    const stateErrorPrefix = 'Bad state: ';
    if (message.startsWith(stateErrorPrefix)) {
      return message.substring(stateErrorPrefix.length);
    }
    return message;
  }
}
