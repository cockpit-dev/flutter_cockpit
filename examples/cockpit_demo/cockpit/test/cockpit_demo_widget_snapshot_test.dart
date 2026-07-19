import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  test('keeps the production main entrypoint free of cockpit bootstrap', () {
    final contents = resolveCockpitDemoFile('lib/main.dart').readAsStringSync();
    expect(contents.contains('flutter_cockpit'), isFalse);
    expect(contents.contains('FlutterCockpit'), isFalse);
  });

  testWidgets(
    'runtime snapshot keeps visible settings targets after navigating from inbox',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(
        tester,
        controller: _testController(),
        database: database,
      );

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final snapshot = rootState.snapshot(
        options: const CockpitSnapshotOptions.investigate(),
      );

      expect(snapshot.routeName, '/settings');
      expect(snapshot.visibleTargets, isNotEmpty);
      expect(
        snapshot.visibleTargets.any(
          (target) =>
              target.text == 'Save settings' ||
              target.tooltip == 'Save settings' ||
              target.text == 'Simulate relay outage',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'runtime snapshot keeps inbox targets visible after returning from task detail',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(
        tester,
        controller: _testController(),
        database: database,
      );

      await createTaskThroughUi(
        tester,
        title: 'Snapshot return guard',
        notes: 'Ensure cockpit can still rediscover inbox after detail closes.',
      );
      await tester.pumpAndSettle();

      await scrollTodoCollectionUntilVisible(
        tester,
        taskRowByTitle('Snapshot return guard'),
      );
      await tester.tap(taskRowByTitle('Snapshot return guard'));
      await settleSingleTapGesture(tester);
      expect(find.text('Task detail'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final snapshot = rootState.snapshot(
        options: const CockpitSnapshotOptions.investigate(),
      );

      expect(snapshot.routeName, '/inbox');
      expect(snapshot.visibleTargets, isNotEmpty);
      expect(
        snapshot.visibleTargets.any(
          (target) =>
              target.keyValue == 'open-task-editor-action' &&
              target.text == 'New task' &&
              target.supportedCommands.contains(CockpitCommandType.tap),
        ),
        isTrue,
      );
      expect(
        snapshot.visibleTargets.any(
          (target) =>
              target.text == 'New task' ||
              target.text == 'Search title or notes' ||
              target.text == 'Snapshot return guard',
        ),
        isTrue,
      );
    },
  );
}

CockpitSessionController _testController() {
  return CockpitSessionController(
    sessionId: 'todo-widget-snapshot-session',
    taskId: 'todo-widget-snapshot-task',
    platform: 'test',
  );
}
