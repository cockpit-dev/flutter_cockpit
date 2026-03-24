import 'package:flutter/material.dart';

import '../../app/todo_app_service.dart';
import '../../model/todo_filter.dart';
import '../../model/todo_priority.dart';
import '../../model/todo_settings.dart';
import '../../model/todo_task.dart';
import '../theme/orbit_todo_theme.dart';
import '../widgets/collection_overview_card.dart';
import '../widgets/editorial_section.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/planning_surface_card.dart';
import '../widgets/task_filter_bar.dart';
import '../widgets/task_list_item.dart';

final class TodoCollectionScreen extends StatefulWidget {
  const TodoCollectionScreen({
    required this.routeName,
    required this.title,
    required this.baseFilter,
    required this.navigationIndex,
    required this.service,
    required this.onOpenEditor,
    required this.onOpenTask,
    required this.onOpenSettings,
    required this.onNavigateToIndex,
    super.key,
  });

  final String routeName;
  final String title;
  final TodoFilter baseFilter;
  final int navigationIndex;
  final TodoAppService service;
  final Future<String?> Function() onOpenEditor;
  final Future<void> Function(TodoTask task) onOpenTask;
  final Future<void> Function() onOpenSettings;
  final void Function(int index) onNavigateToIndex;

  @override
  State<TodoCollectionScreen> createState() => _TodoCollectionScreenState();
}

final class _TodoCollectionScreenState extends State<TodoCollectionScreen> {
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  bool _highPriorityOnly = false;
  final Set<String> _selectedTaskIds = <String>{};
  double _planningZoom = 1.0;
  double _planningZoomAtStart = 1.0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.baseFilter.query);
    _scrollController = ScrollController();
    _highPriorityOnly = widget.baseFilter.priorities.contains(
      TodoPriority.high,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.service.loadTasks(_effectiveFilter());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  TodoFilter _effectiveFilter() {
    final completionFilter = widget.routeName == '/inbox' &&
            widget.service.settingsState.settings.showCompletedInInbox
        ? TodoCompletionFilter.all
        : widget.baseFilter.completionFilter;
    return TodoFilter(
      query: _searchController.text,
      completionFilter: completionFilter,
      priorities: _highPriorityOnly
          ? const <TodoPriority>{TodoPriority.high}
          : widget.baseFilter.priorities,
      tagIds: widget.baseFilter.tagIds,
      includeDeleted: widget.baseFilter.includeDeleted,
      onlyDueToday: widget.baseFilter.onlyDueToday,
    );
  }

  bool get _selectionMode => _selectedTaskIds.isNotEmpty;

  bool _canManualReorder(TodoSettings settings) {
    return widget.routeName == '/inbox' &&
        settings.sortMode == TodoSortMode.manual &&
        _searchController.text.trim().isEmpty &&
        !_highPriorityOnly;
  }

  Future<void> _openEditor() async {
    final savedTaskId = await widget.onOpenEditor();
    if (mounted) {
      await widget.service.loadTasks(_effectiveFilter(), savedTaskId);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handleTaskTap(TodoTask task) async {
    if (_selectionMode) {
      setState(() {
        if (_selectedTaskIds.contains(task.id)) {
          _selectedTaskIds.remove(task.id);
        } else {
          _selectedTaskIds.add(task.id);
        }
      });
      return;
    }

    await widget.onOpenTask(task);
    if (mounted) {
      await widget.service.loadTasks(_effectiveFilter());
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _openSettings() async {
    await widget.onOpenSettings();
    if (!mounted) {
      return;
    }
    await widget.service.loadTasks(_effectiveFilter());
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTaskLongPress(TodoTask task) {
    setState(() {
      _selectedTaskIds.add(task.id);
    });
  }

  Future<void> _quickCompleteTask(TodoTask task) {
    return widget.service.setTaskCompleted(
      taskId: task.id,
      isCompleted: !task.isCompleted,
    );
  }

  Future<void> _deleteSelectedTasks() async {
    final selectedIds = _selectedTaskIds.toList(growable: false);
    for (final taskId in selectedIds) {
      await widget.service.deleteTask(taskId);
    }
    if (mounted) {
      setState(_selectedTaskIds.clear);
    }
  }

  Future<void> _completeSelectedTasks() async {
    final selectedTasks = widget.service.listState.tasks
        .where((task) => _selectedTaskIds.contains(task.id))
        .toList(growable: false);
    for (final task in selectedTasks) {
      await widget.service.setTaskCompleted(taskId: task.id, isCompleted: true);
    }
    if (mounted) {
      setState(_selectedTaskIds.clear);
    }
  }

  void _clearSelection() {
    setState(_selectedTaskIds.clear);
  }

  void _handlePlanningScaleStart(ScaleStartDetails details) {
    _planningZoomAtStart = _planningZoom;
  }

  void _handlePlanningScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _planningZoom = (_planningZoomAtStart * details.scale).clamp(0.9, 1.75);
    });
  }

  Future<void> _handleReorder(int oldIndex, int newIndex) {
    return widget.service.reorderTasks(oldIndex: oldIndex, newIndex: newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final listState = widget.service.listState;
        final settingsState = widget.service.settingsState;
        final tasks = listState.tasks;
        final focusedTask = _taskById(tasks, listState.focusedTaskId);
        final showEmptyState = !listState.isLoading &&
            listState.errorMessage == null &&
            tasks.isEmpty;
        final activeCount = tasks.where((task) => !task.isCompleted).length;
        final dueTodayCount = tasks.where(_isDueToday).length;
        final priorityCount = tasks
            .where(
              (task) =>
                  !task.isCompleted &&
                  (task.priority == TodoPriority.high ||
                      task.priority == TodoPriority.urgent),
            )
            .length;
        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 74,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'ORBIT TODO',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: TextButton.icon(
                  key: const ValueKey<String>('fab-add-task'),
                  onPressed: _openEditor,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New task'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.15,
                    ),
                    shape: const RoundedRectangleBorder(),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey<String>('open-settings-button'),
                tooltip: 'Settings',
                onPressed: _openSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withAlphaFraction(0.82),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _NavigationButton(
                        targetKey: const ValueKey<String>('nav-inbox'),
                        icon: Icons.inbox_rounded,
                        label: 'Inbox',
                        selected: widget.navigationIndex == 0,
                        onPressed: () => widget.onNavigateToIndex(0),
                      ),
                    ),
                    Expanded(
                      child: _NavigationButton(
                        targetKey: const ValueKey<String>('nav-today'),
                        icon: Icons.calendar_today_rounded,
                        label: 'Today',
                        selected: widget.navigationIndex == 1,
                        onPressed: () => widget.onNavigateToIndex(1),
                      ),
                    ),
                    Expanded(
                      child: _NavigationButton(
                        targetKey: const ValueKey<String>('nav-completed'),
                        icon: Icons.task_alt_rounded,
                        label: 'Completed',
                        selected: widget.navigationIndex == 2,
                        onPressed: () => widget.onNavigateToIndex(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
            child: Column(
              children: <Widget>[
                if (listState.pendingUndoTask != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: EditorialSection(
                      backgroundColor: colorScheme.secondaryContainer
                          .withAlphaFraction(0.82),
                      leadingAccentColor: colorScheme.secondary,
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.undo_rounded,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Removed "${listState.pendingUndoTask!.title}" from the board.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const ValueKey<String>('undo-delete-button'),
                            onPressed: widget.service.undoDelete,
                            child: const Text('Undo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_selectionMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: EditorialSection(
                      key: const ValueKey<String>('selection-mode-banner'),
                      backgroundColor: colorScheme.secondaryContainer
                          .withAlphaFraction(0.86),
                      leadingAccentColor: colorScheme.primary,
                      padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.select_all_rounded,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_selectedTaskIds.length} selected',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const ValueKey<String>(
                              'selection-complete-button',
                            ),
                            onPressed: _completeSelectedTasks,
                            child: const Text('Complete'),
                          ),
                          TextButton(
                            key: const ValueKey<String>(
                              'selection-delete-button',
                            ),
                            onPressed: _deleteSelectedTasks,
                            child: const Text('Delete'),
                          ),
                          IconButton(
                            key: const ValueKey<String>(
                              'selection-clear-button',
                            ),
                            tooltip: 'Clear selection',
                            onPressed: _clearSelection,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        widget.service.loadTasks(_effectiveFilter()),
                    child: ListView(
                      key: const ValueKey<String>('todo-collection-scroll'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
                      children: <Widget>[
                        if (focusedTask != null) ...<Widget>[
                          EditorialSection(
                            key: const ValueKey<String>('focused-task-banner'),
                            backgroundColor: colorScheme.primaryContainer
                                .withAlphaFraction(0.84),
                            leadingAccentColor: colorScheme.primary,
                            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        'LATEST UPDATE',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          color: colorScheme.onPrimaryContainer
                                              .withAlphaFraction(0.72),
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.9,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        focusedTask.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.w700,
                                          height: 1.08,
                                        ),
                                      ),
                                      if (focusedTask
                                          .notes.isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 4),
                                        Text(
                                          focusedTask.notes,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: colorScheme
                                                .onPrimaryContainer
                                                .withAlphaFraction(0.74),
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: colorScheme.onPrimaryContainer
                                            .withAlphaFraction(0.1),
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        TextButton(
                                          key: const ValueKey<String>(
                                            'focused-task-open-button',
                                          ),
                                          onPressed: () {
                                            widget.onOpenTask(focusedTask);
                                          },
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                colorScheme.onPrimaryContainer,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 6,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            textStyle: theme
                                                .textTheme.labelMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              const Text('Open'),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.arrow_outward_rounded,
                                                size: 15,
                                                color: colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          key: const ValueKey<String>(
                                            'focused-task-dismiss-button',
                                          ),
                                          tooltip: 'Dismiss latest update',
                                          onPressed:
                                              widget.service.dismissFocusedTask,
                                          visualDensity: VisualDensity.compact,
                                          splashRadius: 16,
                                          constraints:
                                              const BoxConstraints.tightFor(
                                            width: 32,
                                            height: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 17,
                                            color: colorScheme
                                                .onPrimaryContainer
                                                .withAlphaFraction(0.68),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (listState.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: EditorialSection(
                              backgroundColor: colorScheme.errorContainer
                                  .withAlphaFraction(0.88),
                              leadingAccentColor: colorScheme.error,
                              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      listState.errorMessage!,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (listState.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (tasks.isEmpty) ...<Widget>[
                          CollectionOverviewCard(
                            eyebrow: _eyebrowForRoute(),
                            headline: _headlineForRoute(),
                            message: _messageForRoute(),
                            statusBanner:
                                showEmptyState ? 'Fresh canvas' : null,
                            dense: showEmptyState,
                            trailing: _OverviewActionRail(
                              modeTitle: settingsState.settings.compactMode
                                  ? 'Compact'
                                  : 'Comfort',
                              modeSubtitle:
                                  'Sorted ${settingsState.settings.sortMode.name}',
                              onCreateTask: _openEditor,
                            ),
                            metrics: <CollectionMetricData>[
                              CollectionMetricData(
                                label: 'Open',
                                value: '$activeCount',
                                caption: 'Active work in the current view.',
                                icon: Icons.stacked_line_chart_rounded,
                              ),
                              CollectionMetricData(
                                label: 'Today',
                                value: '$dueTodayCount',
                                caption: 'Tasks due before the day closes.',
                                icon: Icons.watch_later_rounded,
                              ),
                              CollectionMetricData(
                                label: 'Priority',
                                value: '$priorityCount',
                                caption: 'High and urgent tasks in the queue.',
                                icon: Icons.priority_high_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (!listState.isLoading && tasks.isEmpty)
                          EmptyStateView(
                            title: 'No tasks yet',
                            message:
                                'Add the first task to establish the queue, then use search, filters, and detail editing as the list grows.',
                            actionLabel: 'Create task',
                            onAction: _openEditor,
                          )
                        else if (!listState.isLoading) ...<Widget>[
                          TaskFilterBar(
                            searchController: _searchController,
                            highPriorityOnly: _highPriorityOnly,
                            onSearchChanged: (_) {
                              widget.service.updateFilter(_effectiveFilter());
                            },
                            onHighPriorityChanged: (selected) {
                              setState(() {
                                _highPriorityOnly = selected;
                              });
                              widget.service.updateFilter(_effectiveFilter());
                            },
                          ),
                          const SizedBox(height: 18),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  'Task list',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const Spacer(),
                                Text(
                                  '${tasks.length} visible',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildTaskList(
                            theme: theme,
                            tasks: tasks,
                            settings: settingsState.settings,
                          ),
                          const SizedBox(height: 18),
                          CollectionOverviewCard(
                            eyebrow: _eyebrowForRoute(),
                            headline: _headlineForRoute(),
                            message: _messageForRoute(),
                            trailing: _OverviewActionRail(
                              modeTitle: settingsState.settings.compactMode
                                  ? 'Compact'
                                  : 'Comfort',
                              modeSubtitle:
                                  'Sorted ${settingsState.settings.sortMode.name}',
                              onCreateTask: _openEditor,
                            ),
                            metrics: <CollectionMetricData>[
                              CollectionMetricData(
                                label: 'Open',
                                value: '$activeCount',
                                caption: 'Active work in the current view.',
                                icon: Icons.stacked_line_chart_rounded,
                              ),
                              CollectionMetricData(
                                label: 'Today',
                                value: '$dueTodayCount',
                                caption: 'Tasks due before the day closes.',
                                icon: Icons.watch_later_rounded,
                              ),
                              CollectionMetricData(
                                label: 'Priority',
                                value: '$priorityCount',
                                caption: 'High and urgent tasks in the queue.',
                                icon: Icons.priority_high_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          PlanningSurfaceCard(
                            tasks: tasks,
                            zoomLevel: _planningZoom,
                            onScaleStart: _handlePlanningScaleStart,
                            onScaleUpdate: _handlePlanningScaleUpdate,
                            onResetZoom: () {
                              setState(() {
                                _planningZoom = 1.0;
                              });
                            },
                          ),
                          if (_canManualReorder(
                            settingsState.settings,
                          )) ...<Widget>[
                            const SizedBox(height: 18),
                            _buildManualQueuePanel(
                              theme: theme,
                              tasks: tasks,
                              compactMode: settingsState.settings.compactMode,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isDueToday(TodoTask task) {
    final dueAt = task.dueAt;
    if (dueAt == null) {
      return false;
    }
    final now = DateTime.now();
    return dueAt.year == now.year &&
        dueAt.month == now.month &&
        dueAt.day == now.day;
  }

  String _eyebrowForRoute() {
    return switch (widget.routeName) {
      '/today' => 'Today',
      '/completed' => 'Completed',
      _ => 'Inbox',
    };
  }

  String _headlineForRoute() {
    return switch (widget.routeName) {
      '/today' => 'Today queue',
      '/completed' => 'Finished work',
      _ => 'Work queue',
    };
  }

  String _messageForRoute() {
    return switch (widget.routeName) {
      '/today' =>
        'Only the commitments due today stay in view, with search and priority filters ready for triage.',
      '/completed' =>
        'Closed tasks remain searchable, reversible, and ready for final review or archive cleanup.',
      _ =>
        'The main queue keeps due dates, urgency, and notes visible without burying the working surface in chrome.',
    };
  }

  Widget _buildTaskList({
    required ThemeData theme,
    required List<TodoTask> tasks,
    required TodoSettings settings,
  }) {
    if (_canManualReorder(settings)) {
      return Column(
        children: tasks
            .map(
              (task) => _buildTaskRow(
                theme: theme,
                task: task,
                compactMode: settings.compactMode,
                isHighlighted:
                    task.id == widget.service.listState.focusedTaskId,
              ),
            )
            .toList(growable: false),
      );
    }

    return Column(
      children: tasks
          .map(
            (task) => _buildTaskRow(
              theme: theme,
              task: task,
              compactMode: settings.compactMode,
              isHighlighted: task.id == widget.service.listState.focusedTaskId,
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildTaskRow({
    required ThemeData theme,
    required TodoTask task,
    required bool compactMode,
    required bool isHighlighted,
  }) {
    return Dismissible(
      key: ValueKey<String>('task-dismiss-${task.id}'),
      direction: DismissDirection.horizontal,
      background: _DismissBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.delete_sweep_rounded,
        label: 'Delete',
      ),
      secondaryBackground: _DismissBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete_sweep_rounded,
        label: 'Delete',
      ),
      onDismissed: (_) {
        widget.service.deleteTask(task.id);
      },
      child: TaskListItem(
        key: ValueKey<String>('task-item-${task.id}'),
        task: task,
        compactMode: compactMode,
        selectionMode: _selectionMode,
        isSelected: _selectedTaskIds.contains(task.id),
        isHighlighted: isHighlighted,
        onTap: () => _handleTaskTap(task),
        onLongPress: () => _handleTaskLongPress(task),
        onDoubleTap: () => _quickCompleteTask(task),
        onToggleCompleted: (value) {
          widget.service.setTaskCompleted(taskId: task.id, isCompleted: value);
        },
      ),
    );
  }

  TodoTask? _taskById(List<TodoTask> tasks, String? taskId) {
    if (taskId == null) {
      return null;
    }
    for (final task in tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  Widget _buildManualQueuePanel({
    required ThemeData theme,
    required List<TodoTask> tasks,
    required bool compactMode,
  }) {
    return EditorialSection(
      key: const ValueKey<String>('manual-queue-panel'),
      backgroundColor: theme.editorialMutedSurfaceColor,
      padding: const EdgeInsets.fromLTRB(0, 22, 0, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Manual queue', style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Drag tasks to set the next execution order.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: (tasks.length * (compactMode ? 92.0 : 104.0)).clamp(
              196.0,
              372.0,
            ),
            child: ReorderableListView.builder(
              key: const ValueKey<String>('manual-queue-list'),
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: tasks.length,
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: Colors.transparent,
                  child: ScaleTransition(
                    scale: Tween<double>(
                      begin: 1,
                      end: 1.03,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              onReorder: _handleReorder,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Padding(
                  key: ValueKey<String>('manual-queue-card-${task.id}'),
                  padding: EdgeInsets.only(
                    bottom: index == tasks.length - 1 ? 0 : 12,
                  ),
                  child: EditorialSection(
                    backgroundColor: theme.editorialSurfaceColor,
                    leadingAccentColor:
                        theme.colorScheme.primary.withAlphaFraction(
                      0.55,
                    ),
                    padding: EdgeInsets.fromLTRB(
                      0,
                      compactMode ? 10 : 12,
                      0,
                      compactMode ? 10 : 12,
                    ),
                    child: Row(
                      children: <Widget>[
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withAlphaFraction(0.82),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Text(
                              '#${index + 1}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                task.title,
                                maxLines: compactMode ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                task.priority.name.toUpperCase(),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ReorderableDragStartListener(
                          index: index,
                          child: Semantics(
                            button: true,
                            label: 'Reorder task ${task.title}',
                            child: Container(
                              key: ValueKey<String>(
                                'task-reorder-handle-${task.id}',
                              ),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: theme.editorialChromeColor,
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant
                                      .withAlphaFraction(0.82),
                                ),
                              ),
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _OverviewActionRail extends StatelessWidget {
  const _OverviewActionRail({
    required this.modeTitle,
    required this.modeSubtitle,
    required this.onCreateTask,
  });

  final String modeTitle;
  final String modeSubtitle;
  final Future<void> Function() onCreateTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        OverviewBadge(title: modeTitle, subtitle: modeSubtitle),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onCreateTask,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create task'),
        ),
      ],
    );
  }
}

final class _DismissBackground extends StatelessWidget {
  const _DismissBackground({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      alignment: alignment,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        border: Border.all(color: colorScheme.error.withAlphaFraction(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

final class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.targetKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Key targetKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return TextButton(
      key: targetKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor:
            selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: const RoundedRectangleBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(height: 6),
          Text(label),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: selected ? 26 : 12,
            height: 2,
            color: selected ? colorScheme.primary : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
