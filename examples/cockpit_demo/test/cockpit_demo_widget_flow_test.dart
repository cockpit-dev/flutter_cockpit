import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/data/todo_repository.dart';
import 'package:cockpit_demo/src/model/todo_filter.dart';
import 'package:cockpit_demo/src/model/todo_priority.dart';
import 'package:cockpit_demo/src/model/todo_task.dart';
import 'dart:io';

import 'support/cockpit_demo_test_support.dart';

void main() {
  test('keeps the production main entrypoint free of cockpit bootstrap', () {
    final contents = File('lib/main.dart').readAsStringSync();
    expect(contents.contains('flutter_cockpit'), isFalse);
    expect(contents.contains('FlutterCockpit'), isFalse);
  });

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

  testWidgets('task editor can clear notes before saving', (tester) async {
    final database = CockpitDemoDatabase.inMemory();
    addCockpitDemoDatabaseTearDown(tester, database);

    await pumpTodoApp(
      tester,
      controller: _testController(),
      database: database,
    );

    await tester.tap(find.byKey(const ValueKey<String>('fab-add-task')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('task-title-input')),
      'Draft delivery summary',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('task-notes-input')),
      'Temporary handoff notes',
    );
    await tester.pumpAndSettle();

    final clearNotesFinder = find.byKey(
      const ValueKey<String>('task-clear-notes-button'),
    );
    expect(clearNotesFinder, findsOneWidget);

    await tester.ensureVisible(clearNotesFinder);
    await tester.pumpAndSettle();
    await tester.tap(clearNotesFinder);
    await tester.pumpAndSettle();

    final notesField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('task-notes-input')),
    );
    expect(notesField.controller?.text, isEmpty);

    await tester.tap(find.byKey(const ValueKey<String>('task-save-button')));
    await tester.pumpAndSettle();

    final createdTasks = await database.select(database.tasks).get();
    expect(createdTasks, hasLength(1));
    expect(createdTasks.single.notes, isEmpty);
  });

  testWidgets(
    'selection mode can select all filtered tasks and apply a batch priority',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);
      final repository = TodoRepository(database);
      final first = await repository.createTask(
        title: 'Prepare production release',
        priority: TodoPriority.low,
      );
      final second = await repository.createTask(
        title: 'Verify modal overlays',
        priority: TodoPriority.medium,
      );
      final third = await repository.createTask(
        title: 'Guard runtime regressions',
        priority: TodoPriority.high,
      );

      await pumpTodoApp(
        tester,
        controller: _testController(),
        database: database,
      );

      await tester.longPress(
        find.byKey(ValueKey<String>('task-open-${first.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey<String>('selection-select-all-button')));
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey<String>('selection-priority-button')));
      await tester.pumpAndSettle();
      expect(find.text('Update priority'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('selection-priority-option-urgent')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('selection-priority-option-urgent')),
      );
      await tester.pumpAndSettle();

      final refreshed = <String, TodoTask>{
        for (final task
            in await repository.fetchTasks(const TodoFilter.inbox()))
          task.id: task,
      };
      expect(refreshed[first.id]?.priority, TodoPriority.urgent);
      expect(refreshed[second.id]?.priority, TodoPriority.urgent);
      expect(refreshed[third.id]?.priority, TodoPriority.urgent);
      expect(
        find.byKey(const ValueKey<String>('selection-mode-banner')),
        findsNothing,
      );
      expect(find.text('URGENT'), findsWidgets);
    },
  );

  testWidgets(
    'selection delete asks for confirmation and undo restores the full batch',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);
      final repository = TodoRepository(database);
      final first = await repository.createTask(title: 'Delete first');
      final second = await repository.createTask(title: 'Delete second');
      await repository.createTask(title: 'Keep me');

      await pumpTodoApp(
        tester,
        controller: _testController(),
        database: database,
      );

      await tester.longPress(
        find.byKey(ValueKey<String>('task-open-${first.id}')),
      );
      await tester.pumpAndSettle();
      await scrollTodoCollectionUntilVisible(
        tester,
        find.byKey(ValueKey<String>('task-open-${second.id}')),
      );
      await tester.tap(find.byKey(ValueKey<String>('task-open-${second.id}')));
      await settleSingleTapGesture(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('selection-delete-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 tasks?'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('selection-delete-cancel-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Delete 2 tasks?'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('selection-mode-banner')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('selection-delete-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('selection-delete-confirm-button')),
      );
      await tester.pumpAndSettle();

      final remaining = await repository.fetchTasks(const TodoFilter.inbox());
      expect(
        remaining.map((task) => task.title).toList(growable: false),
        <String>['Keep me'],
      );
      expect(find.text('Removed 2 tasks from the board.'), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey<String>('undo-delete-button')));
      await tester.pumpAndSettle();

      expect(
        await repository.fetchTasks(const TodoFilter.inbox()),
        hasLength(3),
      );
      expect(
        find.byKey(const ValueKey<String>('selection-mode-banner')),
        findsNothing,
      );
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
