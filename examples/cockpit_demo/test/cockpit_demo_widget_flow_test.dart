import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/data/todo_repository.dart';
import 'package:cockpit_demo/src/model/todo_priority.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets(
    'todo app supports create, edit, complete, search, and settings flows',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(
        tester,
        controller: _testController(),
        database: database,
      );

      expect(
        find.byKey(const ValueKey<String>('fab-add-task')),
        findsOneWidget,
      );
      expect(find.text('Work queue'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('task-search-input')),
        findsNothing,
      );

      await createTaskThroughUi(
        tester,
        title: 'Review remote validation',
        notes: 'Check screenshots and recordings',
        priorityKey: 'task-priority-high',
      );
      await tester.pumpAndSettle();

      final createdTasks = await database.select(database.tasks).get();
      expect(createdTasks.length, 1);
      expect(FlutterCockpit.binding.currentRouteName.value, '/inbox');
      final task = createdTasks.single;
      final taskOpenFinder = find.byKey(
        ValueKey<String>('task-open-${task.id}'),
      );
      await scrollTodoCollectionUntilVisible(tester, taskOpenFinder);
      await tester.tap(taskOpenFinder);
      await settleSingleTapGesture(tester);
      expect(find.text('Task detail'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('detail-edit-button')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('task-title-input')),
        'Review final validation',
      );
      await tester.tap(find.byKey(const ValueKey<String>('task-save-button')));
      await tester.pumpAndSettle();
      expect(find.text('Review final validation'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('detail-complete-toggle')),
      );
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('nav-inbox')));
      await tester.pumpAndSettle();
      await scrollTodoCollectionUntilVisible(
        tester,
        find.byKey(const ValueKey<String>('task-search-input')),
        delta: -220,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('task-search-input')),
        'final',
      );
      await tester.pumpAndSettle();
      expect(find.text('Review final validation'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('open-settings-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('theme-dark-option')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('theme-dark-option')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('compact-mode-switch')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('compact-mode-switch')),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('settings-save-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('settings-save-button')),
      );
      await tester.pumpAndSettle();

      final storedSettings = await (database.select(
        database.appSettings,
      )..limit(1))
          .getSingle();
      expect(storedSettings.compactMode, isTrue);
      expect(storedSettings.themePreference, 'dark');
    },
  );

  testWidgets('todo inbox shows a production empty state before tasks exist', (
    tester,
  ) async {
    final database = CockpitDemoDatabase.inMemory();
    addCockpitDemoDatabaseTearDown(tester, database);

    await pumpTodoApp(
      tester,
      controller: _testController(),
      database: database,
    );

    expect(find.byKey(const ValueKey<String>('fab-add-task')), findsOneWidget);
    expect(find.text('Work queue'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('task-search-input')),
      findsNothing,
    );
  });

  testWidgets(
    'todo inbox does not overflow on a narrow Android-sized viewport with long task content',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(427, 952);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);
      final repository = TodoRepository(database);
      await repository.createTask(
        title:
            'Review runtime diagnostics for the launch bundle before delivery',
        notes:
            'Capture the final screenshot, confirm the recording, and keep the handoff summary readable on Android.',
        priority: TodoPriority.high,
        dueAt: DateTime.utc(2026, 3, 22, 17),
      );

      await pumpTodoApp(
        tester,
        controller: _testController(),
        database: database,
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Review runtime diagnostics'), findsOneWidget);
    },
  );
}

CockpitSessionController _testController() {
  return CockpitSessionController(
    sessionId: 'todo-widget-session',
    taskId: 'todo-widget-task',
    platform: 'test',
  );
}
