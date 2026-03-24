import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';

import 'app/todo_app_service.dart';
import 'data/cockpit_demo_database.dart';
import 'data/todo_repository.dart';
import 'model/todo_settings.dart';
import 'model/todo_filter.dart';
import 'model/todo_task.dart';
import 'network/todo_sync_gateway.dart';
import 'ui/screens/completed_screen.dart';
import 'ui/screens/inbox_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/task_detail_screen.dart';
import 'ui/screens/task_editor_screen.dart';
import 'ui/screens/today_screen.dart';
import 'ui/theme/orbit_todo_theme.dart';

final class CockpitDemoApp extends StatefulWidget {
  CockpitDemoApp({
    FlutterCockpitConfiguration? configuration,
    this.database,
    this.syncGateway,
    super.key,
  })  : initialRouteName =
            configuration == null || configuration.initialRouteName == '/'
                ? '/inbox'
                : configuration.initialRouteName,
        cockpitConfig = FlutterCockpitConfig.fromRuntimeConfiguration(
          (configuration ?? const FlutterCockpitConfiguration()).copyWith(
            initialRouteName:
                configuration == null || configuration.initialRouteName == '/'
                    ? '/inbox'
                    : configuration.initialRouteName,
          ),
        );

  final FlutterCockpitConfig cockpitConfig;
  final CockpitDemoDatabase? database;
  final TodoSyncGatewayClient? syncGateway;
  final String initialRouteName;

  @override
  State<CockpitDemoApp> createState() => _CockpitDemoAppState();
}

final class _CockpitDemoAppState extends State<CockpitDemoApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final CockpitDemoDatabase _database =
      widget.database ?? CockpitDemoDatabase.local();
  late final TodoRepository _repository = TodoRepository(_database);
  late final TodoSyncGatewayClient _syncGateway = widget.syncGateway ??
      TodoLoopbackSyncGateway(payloadBuilder: _buildSyncProbePayload);
  late final TodoAppService _service = TodoAppService(
    repository: _repository,
    syncGateway: _syncGateway,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_service.loadSettings());
  }

  @override
  void dispose() {
    _service.dispose();
    unawaited(_syncGateway.close());
    if (widget.database == null) {
      unawaited(_database.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _service,
      builder: (context, _) {
        return FlutterCockpitApp(
          config: widget.cockpitConfig,
          child: MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Orbit Todo',
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            themeMode: _themeModeFor(_service.settingsState.settings),
            navigatorObservers: <NavigatorObserver>[
              FlutterCockpit.navigatorObserver,
            ],
            initialRoute: widget.initialRouteName,
            onGenerateRoute: _buildRoute,
          ),
        );
      },
    );
  }

  Route<dynamic> _buildRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) {
        switch (settings.name) {
          case '/today':
            return TodayScreen(
              service: _service,
              onOpenEditor: _openEditor,
              onOpenTask: _openTask,
              onOpenSettings: _openSettings,
              onNavigateToIndex: _navigateFromIndex,
            );
          case '/completed':
            return CompletedScreen(
              service: _service,
              onOpenEditor: _openEditor,
              onOpenTask: _openTask,
              onOpenSettings: _openSettings,
              onNavigateToIndex: _navigateFromIndex,
            );
          case '/editor':
            final task = settings.arguments as TodoTask?;
            return TaskEditorScreen(service: _service, task: task);
          case '/detail':
            final task = settings.arguments;
            if (task is! TodoTask) {
              return _fallbackScreen();
            }
            return TaskDetailScreen(
              service: _service,
              repository: _repository,
              task: task,
              onEdit: _editTask,
            );
          case '/settings':
            return SettingsScreen(service: _service);
          case '/inbox':
          default:
            return InboxScreen(
              service: _service,
              onOpenEditor: _openEditor,
              onOpenTask: _openTask,
              onOpenSettings: _openSettings,
              onNavigateToIndex: _navigateFromIndex,
            );
        }
      },
    );
  }

  Future<String?> _openEditor() async {
    final result = await _navigatorKey.currentState!.pushNamed('/editor');
    if (result is String && result.isNotEmpty) {
      return result;
    }
    return null;
  }

  Future<TodoTask?> _editTask(TodoTask task) async {
    await _navigatorKey.currentState!.pushNamed('/editor', arguments: task);
    return _repository.getTask(task.id);
  }

  Future<void> _openTask(TodoTask task) {
    return _navigatorKey.currentState!.pushNamed('/detail', arguments: task);
  }

  Future<void> _openSettings() {
    return _navigatorKey.currentState!.pushNamed('/settings');
  }

  void _navigateFromIndex(int index) {
    final routeName = switch (index) {
      1 => '/today',
      2 => '/completed',
      _ => '/inbox',
    };
    if (FlutterCockpit.binding.currentRouteName.value == routeName) {
      return;
    }
    _navigatorKey.currentState!.pushReplacementNamed(routeName);
  }

  Future<Map<String, Object?>> _buildSyncProbePayload() async {
    final tasks = await _repository.fetchTasks(
      const TodoFilter(completionFilter: TodoCompletionFilter.all),
    );
    final settings = await _repository.readSettings();
    final today = DateTime.now();
    final activeCount = tasks.where((task) => !task.isCompleted).length;
    final completedCount = tasks.where((task) => task.isCompleted).length;
    final dueTodayCount = tasks.where((task) {
      final dueAt = task.dueAt;
      return dueAt != null &&
          dueAt.year == today.year &&
          dueAt.month == today.month &&
          dueAt.day == today.day;
    }).length;

    return <String, Object?>{
      'status': 'ready',
      'mode': 'local-first',
      'summary':
          'Local relay healthy · pending writes 0 · active $activeCount · completed $completedCount',
      'activeTaskCount': activeCount,
      'completedTaskCount': completedCount,
      'dueTodayCount': dueTodayCount,
      'sortMode': settings.sortMode.name,
      'compactMode': settings.compactMode,
      'checkedAt': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Widget _fallbackScreen() {
    return const Scaffold(
      body: Center(child: Text('Unable to load the requested task.')),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return OrbitTodoTheme.build(brightness);
  }

  ThemeMode _themeModeFor(TodoSettings settings) {
    return switch (settings.themePreference) {
      TodoThemePreference.system => ThemeMode.system,
      TodoThemePreference.light => ThemeMode.light,
      TodoThemePreference.dark => ThemeMode.dark,
    };
  }
}
