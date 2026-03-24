import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/data/todo_repository.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets(
    'todo app supports long-press selection and double-tap completion',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);
      final repository = TodoRepository(database);
      final firstTask = await repository.createTask(
        title: 'Review gesture backlog',
        notes: 'Long press should enter selection mode.',
      );
      final secondTask = await repository.createTask(
        title: 'Ship double tap shortcut',
        notes: 'Double tap should complete the task.',
      );

      await pumpTodoApp(
        tester,
        controller: _testController('gesture-selection'),
        database: database,
      );

      final firstOpenFinder = find.byKey(
        ValueKey<String>('task-open-${firstTask.id}'),
      );
      await scrollTodoCollectionUntilVisible(tester, firstOpenFinder);
      await tester.longPress(firstOpenFinder);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('selection-mode-banner')),
        findsOneWidget,
      );
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('selection-clear-button')),
      );
      await tester.pumpAndSettle();

      final secondOpenFinder = find.byKey(
        ValueKey<String>('task-open-${secondTask.id}'),
      );
      await scrollTodoCollectionUntilVisible(tester, secondOpenFinder);
      await tester.tap(secondOpenFinder);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(secondOpenFinder);
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 32));
      await tester.pumpAndSettle();

      final refreshed = await repository.getTask(secondTask.id);
      expect(refreshed?.isCompleted, isTrue);
      expect(find.text('Completed'), findsWidgets);
    },
  );

  testWidgets('todo app supports planning surface pinch zoom', (tester) async {
    final database = CockpitDemoDatabase.inMemory();
    addCockpitDemoDatabaseTearDown(tester, database);
    final repository = TodoRepository(database);
    await repository.createTask(title: 'Queue first');
    await repository.createTask(title: 'Queue second');
    await repository.createTask(title: 'Queue third');

    await pumpTodoApp(
      tester,
      controller: _testController('gesture-zoom'),
      database: database,
    );

    final zoomLabelFinder = find.byKey(
      const ValueKey<String>('planning-surface-zoom-label'),
    );
    final canvasFinder = find.byKey(
      const ValueKey<String>('planning-surface-canvas'),
    );
    await scrollTodoCollectionUntilVisible(tester, canvasFinder);
    final center = tester.getCenter(canvasFinder);
    final leftFinger = await tester.startGesture(
      center.translate(-24, 0),
      pointer: 1,
    );
    final rightFinger = await tester.startGesture(
      center.translate(24, 0),
      pointer: 2,
    );
    await tester.pump();
    await leftFinger.moveTo(center.translate(-80, 0));
    await rightFinger.moveTo(center.translate(80, 0));
    await tester.pump(const Duration(milliseconds: 120));
    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpAndSettle();

    final zoomLabel = tester.widget<Text>(zoomLabelFinder);
    expect(zoomLabel.data, isNot('Canvas 100%'));
  });
}

CockpitSessionController _testController(String suffix) {
  return CockpitSessionController(
    sessionId: 'todo-gesture-$suffix',
    taskId: 'todo-gesture-$suffix-task',
    platform: 'test',
  );
}
