import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/cockpit_demo_app.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets('records a todo flow and writes a task bundle', (tester) async {
    var tick = 0;
    final database = CockpitDemoDatabase.inMemory();
    addCockpitDemoDatabaseTearDown(tester, database);

    final controller = CockpitSessionController(
      sessionId: 'todo-flow-session',
      taskId: 'todo-flow-task',
      platform: 'android',
      now: () => DateTime.utc(2026, 3, 20, 8, 0, tick++),
    );
    final outputRoot = p.join('.dart_tool', 'cockpit_demo_artifacts');
    final outputDirectory = Directory(outputRoot);
    addTearDown(() async {
      if (outputDirectory.existsSync()) {
        await outputDirectory.delete(recursive: true);
      }
    });

    await tester.pumpWidget(
      CockpitDemoApp(
        configuration: FlutterCockpitConfiguration(
          sessionController: controller,
        ),
        database: database,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('fab-add-task')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey<String>('task-title-input')),
      'Review bundle output',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('task-notes-input')),
      'Check manifest and delivery metadata',
    );
    await tester.tap(find.byKey(const ValueKey<String>('task-save-button')));
    await tester.pumpAndSettle();

    final bundle = controller.finish(
      environment: const CockpitEnvironment(
        platform: 'android',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
    );
    final writtenBundle = await tester.runAsync(() async {
      return buildTestBundleWriter().writeBundle(
        bundle: bundle,
        outputRoot: outputRoot,
      );
    });
    final createdTasks = await database.select(database.tasks).get();
    final createdTask = createdTasks.singleWhere(
      (task) => task.title == 'Review bundle output',
    );
    await scrollTodoCollectionUntilVisible(
      tester,
      find.byKey(ValueKey<String>('task-open-${createdTask.id}')),
    );

    expect(writtenBundle, isNotNull);
    expect(find.text('Review bundle output'), findsWidgets);
    expect(
      File(p.join(writtenBundle!.path, 'manifest.json')).existsSync(),
      isTrue,
    );
  });

  testWidgets('captures validation failure while preserving recorded steps', (
    tester,
  ) async {
    var tick = 0;
    final database = CockpitDemoDatabase.inMemory();
    addCockpitDemoDatabaseTearDown(tester, database);

    final controller = CockpitSessionController(
      sessionId: 'todo-flow-failure-session',
      taskId: 'todo-flow-failure-task',
      platform: 'ios',
      now: () => DateTime.utc(2026, 3, 20, 8, 0, tick++),
    );

    await tester.pumpWidget(
      CockpitDemoApp(
        configuration: FlutterCockpitConfiguration(
          sessionController: controller,
        ),
        database: database,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('fab-add-task')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('task-save-button')));
    await tester.pump();

    final bundle = controller.finishWithFailure(
      environment: const CockpitEnvironment(
        platform: 'ios',
        flutterVersion: '3.38.9',
        dartVersion: '3.10.8',
      ),
      failureSummary: 'Task title validation failed.',
    );

    expect(find.text('Task title is required.'), findsOneWidget);
    expect(bundle.manifest.status, CockpitTaskStatus.failed);
    expect(bundle.steps, isNotEmpty);
  });
}
