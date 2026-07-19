import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/data/todo_repository.dart';
import 'package:cockpit_demo/src/model/todo_sync_conflict.dart';
import 'package:cockpit_demo/src/model/todo_task_sync_status.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets(
    'sync conflict flow lets the user isolate and resolve conflicted tasks',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);
      final repository = TodoRepository(database);
      final created = await repository.createTask(title: 'Resolve route copy');
      await repository.applySyncResolution(
        taskId: created.id,
        syncStatus: TodoTaskSyncStatus.conflicted,
        localRevision: 2,
        remoteRevision: 4,
        pendingChanges: const <String>['title'],
        conflict: const TodoSyncConflict(
          type: TodoSyncConflictType.concurrentEdit,
          summary: 'Remote notes changed while local title changed.',
          localFields: <String>['title'],
          remoteFields: <String>['notes'],
        ),
      );

      await pumpTodoApp(tester, database: database);

      await scrollTodoCollectionUntilVisible(
        tester,
        find.text('Conflicts only'),
        delta: -180,
      );
      await tester.tap(find.text('Conflicts only'));
      await tester.pumpAndSettle();

      expect(find.text('Resolve route copy'), findsWidgets);

      await tester.tap(taskRowByTitle('Resolve route copy'));
      await settleSingleTapGesture(tester);
      expect(find.text('Resolve conflict'), findsOneWidget);

      await tester.ensureVisible(find.text('Resolve conflict'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolve conflict'));
      await tester.pumpAndSettle();
      expect(
        find.text('Remote notes changed while local title changed.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Keep local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep local'));
      await tester.pumpAndSettle();

      final refreshed = await repository.getTask(created.id);
      expect(refreshed?.syncStatus, TodoTaskSyncStatus.pending);
      expect(refreshed?.syncConflict, isNull);
    },
  );

  testWidgets(
    'sync conflict flow can recover a task opened from inbox search results',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);
      final repository = TodoRepository(database);
      await repository.createTask(title: 'Backlog cleanup');
      final created = await repository.createTask(
        title: 'Resolve route copy',
        notes: 'Conflict entered through the inbox search results.',
      );
      await repository.applySyncResolution(
        taskId: created.id,
        syncStatus: TodoTaskSyncStatus.conflicted,
        localRevision: 2,
        remoteRevision: 4,
        pendingChanges: const <String>['title'],
        conflict: const TodoSyncConflict(
          type: TodoSyncConflictType.concurrentEdit,
          summary: 'Remote notes changed while local title changed.',
          localFields: <String>['title'],
          remoteFields: <String>['notes'],
        ),
      );

      await pumpTodoApp(tester, database: database);

      await tester.enterText(
        textFieldByLabel('Search title or notes'),
        'Resolve route copy',
      );
      await tester.pumpAndSettle();

      expect(find.text('Resolve route copy'), findsWidgets);
      expect(find.text('Backlog cleanup'), findsNothing);

      await tester.tap(taskRowByTitle('Resolve route copy'));
      await settleSingleTapGesture(tester);

      expect(find.text('Resolve conflict'), findsOneWidget);
      await tester.tap(find.text('Resolve conflict'));
      await tester.pumpAndSettle();
      expect(
        find.text('Remote notes changed while local title changed.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Keep local'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep local'));
      await tester.pumpAndSettle();

      final refreshed = await repository.getTask(created.id);
      expect(refreshed?.syncStatus, TodoTaskSyncStatus.pending);
      expect(refreshed?.syncConflict, isNull);
    },
  );

  testWidgets(
    'detail conflict action stays above the fold on a shorter viewport',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(430, 700);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);
      final repository = TodoRepository(database);
      final created = await repository.createTask(title: 'Resolve route copy');
      await repository.applySyncResolution(
        taskId: created.id,
        syncStatus: TodoTaskSyncStatus.conflicted,
        localRevision: 2,
        remoteRevision: 4,
        pendingChanges: const <String>['title'],
        conflict: const TodoSyncConflict(
          type: TodoSyncConflictType.concurrentEdit,
          summary: 'Remote notes changed while local title changed.',
          localFields: <String>['title'],
          remoteFields: <String>['notes'],
        ),
      );

      await pumpTodoApp(tester, database: database);
      await tester.pumpAndSettle();

      await scrollTodoCollectionUntilVisible(
        tester,
        find.text('Conflicts only'),
        delta: -180,
      );
      await tester.tap(find.text('Conflicts only'));
      await tester.pumpAndSettle();
      await tester.tap(taskRowByTitle('Resolve route copy'));
      await settleSingleTapGesture(tester);

      final conflictButton = find.text('Resolve conflict');
      expect(conflictButton, findsOneWidget);
      final conflictButtonRect = tester.getRect(conflictButton);
      expect(conflictButtonRect.top, lessThanOrEqualTo(700));
      expect(conflictButtonRect.bottom, lessThanOrEqualTo(700));
    },
  );
}
