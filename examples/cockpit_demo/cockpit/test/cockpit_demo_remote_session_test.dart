import 'dart:async';

import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/data/todo_repository.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('exposes the Todo app through the remote session bridge', (
    tester,
  ) async {
    final controller = buildTestController(
      sessionId: 'demo-remote-session',
      taskId: 'demo-remote-task',
      platform: 'android',
    );
    final database = CockpitDemoDatabase.inMemory();
    addCockpitDemoDatabaseTearDown(tester, database);

    await pumpTodoApp(
      tester,
      controller: controller,
      database: database,
      configuration: const FlutterCockpitConfiguration(
        initialRouteName: '/inbox',
        remoteSession: CockpitRemoteSessionConfiguration(
          enabled: true,
          autoStart: false,
          port: 0,
        ),
      ),
    );

    final rootState = tester.state<FlutterCockpitRootState>(
      find.byType(FlutterCockpitRoot),
    );
    final baseUri = await tester.runAsync(() async {
      return rootState.waitForRemoteSession().timeout(
        const Duration(seconds: 5),
      );
    });
    final remoteUri = baseUri!;

    final healthJson = await tester.runAsync(() async {
      return readJson(remoteUri.resolve('/health'));
    });
    final health = CockpitRemoteSessionStatus.fromJson(healthJson!);
    final investigateSnapshotJson = await tester.runAsync(() async {
      return readJson(
        remoteUri.resolve(
          '/snapshot?profile=investigate&includeStyleDetails=true&includeDiagnosticProperties=true',
        ),
      );
    });
    final investigateSnapshot = CockpitSnapshot.fromJson(
      investigateSnapshotJson!,
    );

    expect(health.currentRouteName, '/inbox');
    expect(health.recordingCapabilities.supportsNativeRecording, isFalse);
    expect(health.snapshot.diagnosticLevel, CockpitSnapshotProfile.live);
    expect(
      health.snapshot.visibleTargets.any((target) => target.text == 'New task'),
      isTrue,
    );
    expect(
      health.snapshot.visibleTargets.any(
        (target) => target.text == 'Completed',
      ),
      isTrue,
    );
    expect(
      investigateSnapshot.diagnosticLevel,
      CockpitSnapshotProfile.investigate,
    );
    expect(investigateSnapshot.routeName, '/inbox');
    expect(
      investigateSnapshot.visibleTargets.any(
        (target) => target.text == 'New task',
      ),
      isTrue,
    );
    expect(
      investigateSnapshot.visibleTargets.any(
        (target) => target.text == 'Completed',
      ),
      isTrue,
    );

    final responseJson = await tester.runAsync(() async {
      return postJson(
        remoteUri.resolve('/commands/execute'),
        CockpitCommand(
          commandId: 'remote-assert-empty-state',
          commandType: CockpitCommandType.assertText,
          parameters: const <String, Object?>{'text': 'Work queue'},
        ).toJson(),
      );
    });
    final response = CockpitRemoteCommandResponse.fromJson(responseJson!);

    expect(response.result.success, isTrue);
    expect(response.result.snapshot?['routeName'], '/inbox');
  });

  testWidgets(
    'exposes native semantic labels for task row actions over the remote bridge',
    (tester) async {
      final controller = buildTestController(
        sessionId: 'demo-remote-semantic-session',
        taskId: 'demo-remote-semantic-task',
        platform: 'android',
      );
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(
        tester,
        controller: controller,
        database: database,
        configuration: FlutterCockpitConfiguration(
          initialRouteName: '/inbox',
          remoteSession: CockpitRemoteSessionConfiguration(
            enabled: true,
            autoStart: false,
            port: 0,
          ),
        ),
      );

      await createTaskThroughUi(
        tester,
        title: 'Inspect semantics',
        notes: 'Make row actions discoverable without cockpit markers.',
      );

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final baseUri = await tester.runAsync(() async {
        return rootState.waitForRemoteSession().timeout(
          const Duration(seconds: 5),
        );
      });
      final remoteUri = baseUri!;

      final createdTasks = await database.select(database.tasks).get();
      final task = createdTasks.singleWhere(
        (candidate) => candidate.title == 'Inspect semantics',
      );
      await scrollTodoCollectionUntilVisible(
        tester,
        taskRowByTitle(task.title),
      );

      final snapshotJson = await tester.runAsync(() async {
        return readJson(
          remoteUri.resolve(
            '/snapshot?profile=investigate&includeDiagnosticProperties=true',
          ),
        );
      });
      final snapshot = CockpitSnapshot.fromJson(snapshotJson!);

      expect(
        snapshot.visibleTargets.any(
          (target) => target.semanticId == 'Open task Inspect semantics',
        ),
        isTrue,
      );
      expect(
        snapshot.visibleTargets.any(
          (target) => target.semanticId == 'Complete task Inspect semantics',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'exposes normalized typography diagnostics for the Todo detail title over the remote bridge',
    (tester) async {
      final controller = buildTestController(
        sessionId: 'demo-remote-detail-session',
        taskId: 'demo-remote-detail-task',
        platform: 'android',
      );
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(
        tester,
        controller: controller,
        database: database,
        configuration: const FlutterCockpitConfiguration(
          initialRouteName: '/inbox',
          remoteSession: CockpitRemoteSessionConfiguration(
            enabled: true,
            autoStart: false,
            port: 0,
          ),
        ),
      );

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final baseUri = await tester.runAsync(() async {
        return rootState.waitForRemoteSession().timeout(
          const Duration(seconds: 5),
        );
      });
      final remoteUri = baseUri!;

      await createTaskThroughUi(
        tester,
        title: 'Inspect typography',
        notes: 'Review the final heading style through the remote bridge.',
      );
      final createdTasks = await database.select(database.tasks).get();
      final task = createdTasks.singleWhere(
        (candidate) => candidate.title == 'Inspect typography',
      );
      final taskOpenFinder = taskRowByTitle(task.title);
      await scrollTodoCollectionUntilVisible(tester, taskOpenFinder);
      await tester.tap(taskOpenFinder);
      await settleSingleTapGesture(tester);

      final successSnapshotJson = await tester.runAsync(() async {
        return readJson(
          remoteUri.resolve(
            '/snapshot?profile=investigate&includeStyleDetails=true&includeDiagnosticProperties=true',
          ),
        );
      });
      final successSnapshot = CockpitSnapshot.fromJson(successSnapshotJson!);
      final diagnosticTarget = successSnapshot.visibleTargets.firstWhere(
        (target) => _propertyValue(target, 'Font Size') != null,
      );

      expect(_propertyValue(diagnosticTarget, 'Font Weight'), isNotNull);
      expect(_propertyValue(diagnosticTarget, 'Font Size'), isNotNull);
      expect(_propertyValue(diagnosticTarget, 'Text Color'), isNotNull);
      expect(diagnosticTarget.layout, isNotNull);
      expect(successSnapshot.routeName, '/detail');
    },
  );

  testWidgets(
    'supports scrollUntilVisible over the remote bridge for long settings content',
    (tester) async {
      final controller = buildTestController(
        sessionId: 'demo-remote-scroll-session',
        taskId: 'demo-remote-scroll-task',
        platform: 'ios',
      );
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      await pumpTodoApp(
        tester,
        controller: controller,
        database: database,
        configuration: const FlutterCockpitConfiguration(
          initialRouteName: '/settings',
          remoteSession: CockpitRemoteSessionConfiguration(
            enabled: true,
            autoStart: false,
            port: 0,
          ),
        ),
      );

      final rootState = tester.state<FlutterCockpitRootState>(
        find.byType(FlutterCockpitRoot),
      );
      final baseUri = await tester.runAsync(() async {
        return rootState.waitForRemoteSession().timeout(
          const Duration(seconds: 5),
        );
      });
      final remoteUri = baseUri!;
      CockpitRemoteCommandResponse? response;
      for (var attempt = 0; attempt < 8; attempt += 1) {
        final responseJson = await tester.runAsync(() async {
          return postJson(
            remoteUri.resolve('/commands/execute'),
            CockpitCommand(
              commandId: 'scroll-settings-diagnostics-$attempt',
              commandType: CockpitCommandType.scrollUntilVisible,
              locator: const CockpitLocator(text: 'Acceptance bundles'),
              parameters: const <String, Object?>{
                'maxScrolls': 1,
                'viewportFraction': 0.8,
              },
            ).toJson(),
          );
        });
        response = CockpitRemoteCommandResponse.fromJson(responseJson!);
        await tester.pump();
        await tester.pump();
        if (response.result.success) {
          break;
        }
      }

      expect(
        response?.result.success,
        isTrue,
        reason:
            '${response?.result.error?.code}: ${response?.result.error?.message}',
      );
      expect(find.text('Acceptance bundles'), findsOneWidget);
    },
  );

  testWidgets('executes production gesture flows over the remote bridge', (
    tester,
  ) async {
    final controller = buildTestController(
      sessionId: 'demo-remote-gesture-session',
      taskId: 'demo-remote-gesture-task',
      platform: 'android',
    );
    final database = CockpitDemoDatabase.inMemory();
    addCockpitDemoDatabaseTearDown(tester, database);
    final repository = TodoRepository(database);
    final firstTask = await repository.createTask(
      title: 'Remote long press selection',
    );
    final secondTask = await repository.createTask(
      title: 'Remote double tap completion',
    );
    await repository.createTask(title: 'Remote delayed reorder');

    await pumpTodoApp(
      tester,
      controller: controller,
      database: database,
      configuration: FlutterCockpitConfiguration(
        initialRouteName: '/inbox',
        remoteSession: const CockpitRemoteSessionConfiguration(
          enabled: true,
          autoStart: false,
          port: 0,
        ),
      ),
    );

    final rootState = tester.state<FlutterCockpitRootState>(
      find.byType(FlutterCockpitRoot),
    );
    final baseUri = await tester.runAsync(() async {
      return rootState.waitForRemoteSession().timeout(
        const Duration(seconds: 5),
      );
    });
    final remoteUri = baseUri!;

    Future<CockpitRemoteCommandResponse> executeRemote(
      CockpitCommand command,
    ) async {
      final responseJson = await tester.runAsync(() async {
        return postJson(
          remoteUri.resolve('/commands/execute'),
          command.toJson(),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException(
            'Timed out waiting for remote command ${command.commandId}.',
          ),
        );
      });
      return CockpitRemoteCommandResponse.fromJson(responseJson!);
    }

    Future<void> settleUi(String label) {
      return tester
          .pumpAndSettle(
            const Duration(milliseconds: 100),
            EnginePhase.sendSemanticsUpdate,
            const Duration(seconds: 5),
          )
          .timeout(
            const Duration(seconds: 6),
            onTimeout: () => throw TimeoutException(
              'Timed out waiting for UI to settle after $label.',
            ),
          );
    }

    await scrollTodoCollectionUntilVisible(
      tester,
      taskRowByTitle(firstTask.title),
    );
    final longPressResponse = await executeRemote(
      CockpitCommand(
        commandId: 'remote-long-press-selection',
        commandType: CockpitCommandType.longPress,
        locator: CockpitLocator(
          semanticId: 'Open task ${firstTask.title}',
          ancestor: const CockpitLocator(route: '/inbox'),
        ),
      ),
    );
    expect(longPressResponse.result.success, isTrue);
    await settleUi('remote long press');
    expect(find.text('1 selected'), findsOneWidget);

    final clearSelectionResponse = await executeRemote(
      CockpitCommand(
        commandId: 'remote-clear-selection',
        commandType: CockpitCommandType.tap,
        locator: const CockpitLocator(
          tooltip: 'Clear selection',
          ancestor: CockpitLocator(route: '/inbox'),
        ),
      ),
    );
    expect(clearSelectionResponse.result.success, isTrue);
    await settleUi('remote clear selection');
    expect(find.textContaining('selected'), findsNothing);

    await scrollTodoCollectionUntilVisible(
      tester,
      taskRowByTitle(secondTask.title),
    );
    final doubleTapResponse = await executeRemote(
      CockpitCommand(
        commandId: 'remote-double-tap-complete',
        commandType: CockpitCommandType.doubleTap,
        locator: CockpitLocator(
          semanticId: 'Open task ${secondTask.title}',
          ancestor: const CockpitLocator(route: '/inbox'),
        ),
      ),
    );
    expect(doubleTapResponse.result.success, isTrue);
    await settleUi('remote double tap');
    expect(find.text('Completed'), findsWidgets);
  });
}

String? _propertyValue(CockpitSnapshotTarget target, String name) {
  for (final property in target.diagnosticProperties) {
    if (property.name == name) {
      return property.value;
    }
  }
  return null;
}
