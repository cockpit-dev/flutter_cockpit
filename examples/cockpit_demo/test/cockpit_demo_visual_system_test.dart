import 'package:flutter/material.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/cockpit_demo_app.dart';
import 'package:cockpit_demo/src/ui/theme/orbit_todo_theme.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets(
    'todo inbox presents a branded overview surface with expressive typography',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await tester.pumpWidget(
        CockpitDemoApp(
          configuration: FlutterCockpitConfiguration(
            sessionController: _testController(),
          ),
          database: database,
        ),
      );
      await tester.pumpAndSettle();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      final headlineMedium = materialApp.theme!.textTheme.headlineMedium;

      expect(headlineMedium?.fontFamily, isNotNull);
      expect(
        find.byKey(const ValueKey<String>('collection-overview-card')),
        findsOneWidget,
      );
      expect(find.text('INBOX'), findsOneWidget);
      expect(find.text('Work queue'), findsOneWidget);
      expect(
        find.text(
          'The main queue keeps due dates, urgency, and notes visible without burying the working surface in chrome.',
        ),
        findsOneWidget,
      );
      expect(find.text('OPEN'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('PRIORITY'), findsOneWidget);
    },
  );

  testWidgets(
    'settings screen groups preferences into production-style control sections',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await tester.pumpWidget(
        CockpitDemoApp(
          configuration: FlutterCockpitConfiguration(
            sessionController: _testController(),
          ),
          database: database,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('open-settings-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('settings-appearance-card')),
        findsOneWidget,
      );
      expect(find.byType(Card), findsNothing);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Tune the workspace.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Workflow defaults'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('settings-workflow-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('settings-delivery-card')),
        findsOneWidget,
      );
      expect(find.text('Workflow defaults'), findsOneWidget);
      expect(find.text('Storage and delivery'), findsOneWidget);
      expect(find.text('Use compact task rows'), findsOneWidget);
    },
  );

  test('dark theme keeps editorial panels in a dark readable range', () {
    final darkTheme = OrbitTodoTheme.build(Brightness.dark);

    expect(darkTheme.editorialSurfaceColor.computeLuminance(), lessThan(0.08));
    expect(
      darkTheme.editorialMutedSurfaceColor.computeLuminance(),
      lessThan(0.08),
    );
    expect(darkTheme.editorialChromeColor.computeLuminance(), lessThan(0.13));
  });
}

CockpitSessionController _testController() {
  return CockpitSessionController(
    sessionId: 'todo-visual-session',
    taskId: 'todo-visual-task',
    platform: 'test',
  );
}
