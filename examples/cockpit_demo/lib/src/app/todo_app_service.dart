import 'package:flutter/foundation.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import '../data/todo_repository.dart';
import '../model/todo_filter.dart';
import '../model/todo_priority.dart';
import '../model/todo_settings.dart';
import '../model/todo_tag.dart';
import '../model/todo_task.dart';
import '../network/todo_sync_gateway.dart';
import 'todo_editor_state.dart';
import 'todo_list_state.dart';
import 'todo_settings_state.dart';
import 'todo_sync_state.dart';

final class TodoAppService extends ChangeNotifier {
  TodoAppService({
    required TodoRepositoryClient repository,
    TodoSyncGatewayClient? syncGateway,
  })  : _repository = repository,
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
      _recordWorkflowIssue(
        actionType: 'validation_error',
        message: validationMessage,
        details: const <String, Object?>{
          'field': 'title',
          'screen': 'task_editor',
        },
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
      _editorState = TodoEditorState.empty;
      await loadTasks(_listState.filter, savedTask.id);
      return savedTask;
    } on Object catch (error) {
      if (_isDisposed) {
        return null;
      }
      final message = _errorMessage(error);
      _editorState = _editorState.copyWith(
        isSaving: false,
        validationMessage: () => message,
      );
      _recordWorkflowIssue(
        actionType: 'save_error',
        message: message,
        details: <String, Object?>{
          'screen': 'task_editor',
          'existingTaskId': existingTaskId,
        },
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
      await _repository.updateTasksTags(
        taskIds: normalizedIds,
        tagIds: tagIds,
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
        lastHealthyEndpoint:
            isHealthy ? () => result.endpoint.toString() : null,
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

  void _recordWorkflowIssue({
    required String actionType,
    required String message,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    final snapshot = FlutterCockpit.binding.registry.snapshot();
    FlutterCockpit.recordStep(
      actionType: actionType,
      actionArgs: <String, Object?>{'message': message, ...details},
      observation: CockpitObservation(
        routeName: FlutterCockpit.binding.currentRouteName.value,
        interactiveElements: snapshot.visibleTargets
            .map((target) => target.displayLabel)
            .whereType<String>()
            .take(12)
            .toList(growable: false),
        phase: CockpitObservationPhase.failure,
      ),
      snapshot: snapshot,
    );
  }
}
