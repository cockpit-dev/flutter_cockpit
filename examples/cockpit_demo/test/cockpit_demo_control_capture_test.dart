import 'package:flutter/widgets.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/cockpit_demo_app.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets(
    'reveals long settings ledger content through the in-app executor',
    (tester) async {
      final controller = CockpitSessionController(
        sessionId: 'settings-scroll-session',
        taskId: 'settings-scroll-task',
        platform: 'ios',
      );
      final registry = CockpitTargetRegistry(routeName: '/settings');
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await tester.pumpWidget(
        CockpitDemoApp(
          configuration: FlutterCockpitConfiguration(
            initialRouteName: '/settings',
            sessionController: controller,
            registry: registry,
          ),
          database: database,
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        waitTickHandler: tester.pump,
        scrollStepHandler: ({
          required reverse,
          required viewportFraction,
          scrollableKey,
          required duration,
          required gestureProfile,
          required continuous,
          required postScrollEnsureVisible,
        }) {
          return surfaceState.scrollByViewport(
            reverse: reverse,
            viewportFraction: viewportFraction,
            scrollableKey: scrollableKey,
            duration: duration,
            gestureProfile: gestureProfile,
            continuous: continuous,
            postScrollEnsureVisible: postScrollEnsureVisible,
          );
        },
        ensureVisibleHandler: ({
          required locator,
          required duration,
          required alignment,
          required padding,
        }) {
          return surfaceState.ensureLocatorVisible(
            locator,
            duration: duration,
            alignment: alignment,
            padding: padding,
          );
        },
      );

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-scroll-settings-ledger',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(
            kind: CockpitLocatorKind.text,
            value: 'Acceptance bundles',
          ),
          parameters: const <String, Object?>{
            'maxScrolls': 8,
            'viewportFraction': 0.8,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(result.success, isTrue, reason: result.error?.message);
      expect(find.text('Acceptance bundles'), findsOneWidget);
    },
  );

  testWidgets(
    'reveals diagnostics controls through the in-app executor',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(390, 844) * 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = CockpitSessionController(
        sessionId: 'settings-diagnostics-scroll-session',
        taskId: 'settings-diagnostics-scroll-task',
        platform: 'ios',
      );
      final registry = CockpitTargetRegistry(routeName: '/settings');
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await tester.pumpWidget(
        CockpitDemoApp(
          configuration: FlutterCockpitConfiguration(
            initialRouteName: '/settings',
            sessionController: controller,
            registry: registry,
          ),
          database: database,
        ),
      );
      await tester.pumpAndSettle();

      final surfaceState = tester.state<CockpitSurfaceState>(
        find.byType(CockpitSurface),
      );
      final executor = InAppCockpitCommandExecutor(
        registry: registry,
        snapshotProvider: surfaceState.snapshot,
        waitTickHandler: tester.pump,
        scrollStepHandler: ({
          required reverse,
          required viewportFraction,
          scrollableKey,
          required duration,
          required gestureProfile,
          required continuous,
          required postScrollEnsureVisible,
        }) {
          return surfaceState.scrollByViewport(
            reverse: reverse,
            viewportFraction: viewportFraction,
            scrollableKey: scrollableKey,
            duration: duration,
            gestureProfile: gestureProfile,
            continuous: continuous,
            postScrollEnsureVisible: postScrollEnsureVisible,
          );
        },
        ensureVisibleHandler: ({
          required locator,
          required duration,
          required alignment,
          required padding,
        }) {
          return surfaceState.ensureLocatorVisible(
            locator,
            duration: duration,
            alignment: alignment,
            padding: padding,
          );
        },
      );

      final revealSyncCheck = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-scroll-settings-sync-check',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(
            kind: CockpitLocatorKind.text,
            value: 'Run check',
          ),
          parameters: const <String, Object?>{
            'maxScrolls': 8,
            'viewportFraction': 0.82,
            'continuous': true,
            'durationPerStepMs': 220,
          },
        ),
      );
      await tester.pumpAndSettle();

      final runSyncCheck = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-run-sync-check',
          commandType: CockpitCommandType.tap,
          locator: const CockpitLocator(
            kind: CockpitLocatorKind.text,
            value: 'Run check',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = await executor.execute(
        CockpitCommand(
          commandId: 'cmd-scroll-settings-diagnostics',
          commandType: CockpitCommandType.scrollUntilVisible,
          locator: const CockpitLocator(
            kind: CockpitLocatorKind.text,
            value: 'Emit debug log',
          ),
          parameters: const <String, Object?>{
            'maxScrolls': 8,
            'viewportFraction': 0.82,
            'continuous': true,
            'durationPerStepMs': 220,
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(revealSyncCheck.success, isTrue,
          reason: revealSyncCheck.error?.message);
      expect(runSyncCheck.success, isTrue, reason: runSyncCheck.error?.message);
      expect(result.success, isTrue, reason: result.error?.message);
      expect(find.text('Emit debug log'), findsOneWidget);
    },
  );

  testWidgets(
    'discovers native Todo targets and executes the creation flow through the in-app executor',
    (tester) async {
      final controller = CockpitSessionController(
        sessionId: 'capture-session',
        taskId: 'capture-task',
        platform: 'android',
      );
      final registry = CockpitTargetRegistry(routeName: '/inbox');
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await tester.pumpWidget(
        CockpitDemoApp(
          configuration: FlutterCockpitConfiguration(
            sessionController: controller,
            registry: registry,
          ),
          database: database,
        ),
      );
      await tester.pumpAndSettle();

      InAppCockpitCommandExecutor executorForCurrentRoute() {
        final surfaceState = tester.state<CockpitSurfaceState>(
          find.byType(CockpitSurface),
        );
        return InAppCockpitCommandExecutor(
          registry: registry,
          snapshotProvider: surfaceState.snapshot,
          waitTickHandler: tester.pump,
          scrollStepHandler: ({
            required reverse,
            required viewportFraction,
            scrollableKey,
            required duration,
            required gestureProfile,
            required continuous,
            required postScrollEnsureVisible,
          }) {
            return surfaceState.scrollByViewport(
              reverse: reverse,
              viewportFraction: viewportFraction,
              scrollableKey: scrollableKey,
              duration: duration,
              gestureProfile: gestureProfile,
              continuous: continuous,
              postScrollEnsureVisible: postScrollEnsureVisible,
            );
          },
        );
      }

      expect(
        registry
            .resolve(
              const CockpitLocator(
                kind: CockpitLocatorKind.key,
                value: 'fab-add-task',
              ),
            )
            .isSuccess,
        isTrue,
      );

      final openEditorCommand = CockpitCommand(
        commandId: 'cmd-open-editor',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(
          kind: CockpitLocatorKind.key,
          value: 'fab-add-task',
        ),
      );
      controller.recordCommandResult(
        openEditorCommand,
        await executorForCurrentRoute().execute(openEditorCommand),
      );
      await tester.pumpAndSettle();

      final enterTitleCommand = CockpitCommand(
        commandId: 'cmd-enter-title',
        commandType: CockpitCommandType.enterText,
        locator: const CockpitLocator(
          kind: CockpitLocatorKind.key,
          value: 'task-title-input',
        ),
        parameters: const <String, Object?>{'text': 'Review diagnostics'},
      );
      controller.recordCommandResult(
        enterTitleCommand,
        await executorForCurrentRoute().execute(enterTitleCommand),
      );
      await tester.pumpAndSettle();

      final saveTaskCommand = CockpitCommand(
        commandId: 'cmd-save-task',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(
          kind: CockpitLocatorKind.key,
          value: 'task-save-button',
        ),
      );
      controller.recordCommandResult(
        saveTaskCommand,
        await executorForCurrentRoute().execute(saveTaskCommand),
      );
      await tester.pumpAndSettle();

      final createdTasks = await database.select(database.tasks).get();
      final createdTask = createdTasks.single;
      final taskOpenKey = 'task-open-${createdTask.id}';

      final revealTaskCommand = CockpitCommand(
        commandId: 'cmd-scroll-to-task',
        commandType: CockpitCommandType.scrollUntilVisible,
        locator: CockpitLocator(
          kind: CockpitLocatorKind.key,
          value: taskOpenKey,
        ),
        parameters: const <String, Object?>{
          'scrollableKey': 'todo-collection-scroll',
          'maxScrolls': 8,
          'viewportFraction': 0.72,
        },
      );
      controller.recordCommandResult(
        revealTaskCommand,
        await executorForCurrentRoute().execute(revealTaskCommand),
      );
      await tester.pumpAndSettle();

      final assertTaskVisibleCommand = CockpitCommand(
        commandId: 'cmd-assert-task-visible',
        commandType: CockpitCommandType.assertVisible,
        locator: CockpitLocator(
          kind: CockpitLocatorKind.key,
          value: taskOpenKey,
        ),
      );
      controller.recordCommandResult(
        assertTaskVisibleCommand,
        await executorForCurrentRoute().execute(assertTaskVisibleCommand),
      );

      expect(find.byKey(ValueKey<String>(taskOpenKey)), findsOneWidget);

      final bundle = controller.finish(
        environment: const CockpitEnvironment(
          platform: 'android',
          flutterVersion: '3.38.9',
          dartVersion: '3.10.8',
        ),
        capabilitiesUsed: const <String>['inAppControl'],
      );

      expect(bundle.manifest.commandCount, 5);
      expect(
        bundle.steps
            .where((step) => step.commandType != null)
            .map((step) => step.status),
        everyElement(CockpitCommandStatus.succeeded),
      );
      expect(
        bundle.steps
            .where((step) => step.commandType != null)
            .map((step) => step.commandType),
        <CockpitCommandType>[
          CockpitCommandType.tap,
          CockpitCommandType.enterText,
          CockpitCommandType.tap,
          CockpitCommandType.scrollUntilVisible,
          CockpitCommandType.assertVisible,
        ],
      );
    },
  );
}
