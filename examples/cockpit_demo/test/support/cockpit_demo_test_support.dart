import 'package:drift/drift.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/cockpit_demo_app.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/network/todo_sync_gateway.dart';
import 'package:cockpit_demo/src/ui/screens/task_editor_screen.dart';
import 'package:cockpit_demo/src/ui/screens/todo_collection_screen.dart';
import 'package:cockpit_demo/src/ui/widgets/editorial_section.dart';

bool _cockpitDemoTestRuntimeConfigured = false;

void _ensureCockpitDemoTestRuntimeConfigured() {
  if (_cockpitDemoTestRuntimeConfigured) {
    return;
  }
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  _cockpitDemoTestRuntimeConfigured = true;
}

void addCockpitDemoDatabaseTearDown(
  WidgetTester tester,
  CockpitDemoDatabase database,
) {
  _ensureCockpitDemoTestRuntimeConfigured();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await database.close();
  });
}

Future<void> pumpTodoApp(
  WidgetTester tester, {
  required CockpitDemoDatabase database,
  TodoSyncGatewayClient? syncGateway,
}) async {
  _ensureCockpitDemoTestRuntimeConfigured();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  await tester.pumpWidget(
    buildCockpitDemoApp(database: database, syncGateway: syncGateway),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
  await tester.pumpAndSettle();
}

Widget buildCockpitDemoApp({
  CockpitDemoDatabase? database,
  TodoSyncGatewayClient? syncGateway,
}) {
  return CockpitDemoApp(
    initialRouteName: '/inbox',
    database: database,
    syncGateway: syncGateway,
  );
}

Future<void> createTaskThroughUi(
  WidgetTester tester, {
  required String title,
  String notes = '',
  String? priorityLabel,
  String? dueLabel,
}) async {
  await tester.tap(find.text('New task'));
  await tester.pumpAndSettle();
  await tester.enterText(textFieldByLabel('Task title'), title);
  if (notes.isNotEmpty) {
    await tester.enterText(textFieldByLabel('Notes'), notes);
  }
  if (priorityLabel != null) {
    final priorityFinder = find.widgetWithText(
      ChoiceChip,
      priorityLabel.toUpperCase(),
    );
    await _scrollUntilVisible(tester, priorityFinder);
    await tester.tap(priorityFinder);
    await tester.pumpAndSettle();
  }
  if (dueLabel != null) {
    final dueFinder = find.widgetWithText(ChoiceChip, dueLabel);
    await _scrollUntilVisible(tester, dueFinder);
    await tester.tap(dueFinder);
    await tester.pumpAndSettle();
  }
  final saveFinder = find.text('Save task');
  await _scrollUntilVisible(tester, saveFinder);
  await tester.tap(saveFinder);
  await tester.pumpAndSettle();
  await settleAfterTaskSave(tester);
}

Future<void> settleAfterTaskSave(WidgetTester tester) async {
  for (var attempt = 0; attempt < 12; attempt += 1) {
    final routeSettled = find.byType(TaskEditorScreen).evaluate().isEmpty;
    final spinnerSettled = find
        .byType(CircularProgressIndicator)
        .evaluate()
        .isEmpty;
    final collectionFinder = find.byType(TodoCollectionScreen);
    final collectionSettled =
        collectionFinder.evaluate().isEmpty ||
        !tester
            .state<State<TodoCollectionScreen>>(collectionFinder)
            .widget
            .service
            .listState
            .isLoading;
    if (routeSettled && spinnerSettled && collectionSettled) {
      break;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> _scrollUntilVisible(WidgetTester tester, Finder finder) async {
  await tester
      .scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).first,
      )
      .timeout(const Duration(seconds: 10));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<void> settleSingleTapGesture(WidgetTester tester) async {
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 32));
  await tester.pumpAndSettle();
}

Future<void> scrollTodoCollectionUntilVisible(
  WidgetTester tester,
  Finder finder, {
  double delta = 220,
}) async {
  final collection = find.byType(TodoCollectionScreen);
  final scrollable = collection.evaluate().isNotEmpty
      ? find.descendant(of: collection, matching: find.byType(Scrollable)).first
      : find.byType(Scrollable).first;
  await tester
      .scrollUntilVisible(finder, delta, scrollable: scrollable)
      .timeout(const Duration(seconds: 10));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Finder textFieldByLabel(String label) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is TextField &&
        (widget.decoration?.labelText == label ||
            widget.decoration?.hintText == label),
    description: 'TextField($label)',
  );
}

Finder taskRowByTitle(String title, {bool selectionMode = false}) {
  return find.ancestor(of: find.text(title), matching: find.byType(InkWell));
}

Finder manualQueueReorderHandle(String title) {
  final manualQueueTitle = find.text(title).last;
  final cardFinder = find.ancestor(
    of: manualQueueTitle,
    matching: find.byType(EditorialSection),
  );
  return find.descendant(
    of: cardFinder.first,
    matching: find.byIcon(Icons.drag_indicator_rounded),
  );
}

Finder navigationButton(String label) {
  return find.ancestor(
    of: find.text(label).last,
    matching: find.byType(TextButton),
  );
}

Finder planningSurfaceCanvas() {
  return find.byWidgetPredicate(
    (widget) => widget is GestureDetector && widget.onScaleUpdate != null,
    description: 'Planning surface canvas',
  );
}
