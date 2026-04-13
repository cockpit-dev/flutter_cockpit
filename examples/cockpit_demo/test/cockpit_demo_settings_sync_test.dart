import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/app/todo_app_service.dart';
import 'package:cockpit_demo/src/app/todo_sync_state.dart';
import 'package:cockpit_demo/src/data/cockpit_demo_database.dart';
import 'package:cockpit_demo/src/data/todo_repository.dart';
import 'package:cockpit_demo/src/network/todo_sync_contract.dart';
import 'package:cockpit_demo/src/ui/screens/settings_screen.dart';
import 'package:cockpit_demo/src/network/todo_sync_gateway.dart';

import 'support/cockpit_demo_test_support.dart';

void main() {
  testWidgets(
    'settings screen supports simulated relay outage and retry recovery',
    (tester) async {
      final database = CockpitDemoDatabase.inMemory();
      addCockpitDemoDatabaseTearDown(tester, database);

      final repository = TodoRepository(database);
      late final TodoAppService service;
      final gateway = _ConfigurableTodoSyncGateway(
        shouldSimulateFailure: () => service.syncState.simulateFailure,
      );

      service = TodoAppService(repository: repository, syncGateway: gateway);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(service: service)),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Sync relay idle'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Sync relay idle'), findsOneWidget);
      expect(find.text('Sync relay idle'), findsOneWidget);
      expect(find.text('Run check'), findsOneWidget);

      await service.runSyncHealthCheck();
      await tester.pumpAndSettle();

      expect(service.syncState.status, TodoSyncStatus.healthy);
      expect(service.syncState.headline, 'Relay ready');
      expect(service.syncState.detail, contains('pending writes 0'));

      await tester.ensureVisible(find.text('Simulate relay outage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate relay outage'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Run check'));
      await tester.pumpAndSettle();
      await service.runSyncHealthCheck();
      await tester.pumpAndSettle();

      expect(service.syncState.status, TodoSyncStatus.failed);
      expect(service.syncState.headline, 'Relay degraded');
      expect(find.text('Retry now'), findsOneWidget);
      expect(find.text('Last successful check'), findsOneWidget);
      expect(find.textContaining('pending writes 0'), findsWidgets);

      await tester.ensureVisible(find.text('Simulate relay outage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simulate relay outage'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Retry now'));
      await tester.pumpAndSettle();
      await service.runSyncHealthCheck();
      await tester.pumpAndSettle();

      expect(service.syncState.status, TodoSyncStatus.healthy);
      expect(service.syncState.headline, 'Relay ready');
      expect(find.text('Run check'), findsOneWidget);

      await tester.ensureVisible(find.text('Reset relay state'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset relay state'));
      await tester.pumpAndSettle();

      expect(service.syncState.status, TodoSyncStatus.idle);
      expect(service.syncState.headline, 'Sync relay idle');
      expect(find.text('Run check'), findsOneWidget);
      expect(find.text('Last successful check'), findsNothing);
    },
  );
}

final class _ConfigurableTodoSyncGateway implements TodoSyncGatewayClient {
  _ConfigurableTodoSyncGateway({required this.shouldSimulateFailure});

  final bool Function() shouldSimulateFailure;

  @override
  Future<void> close() async {}

  @override
  Future<TodoSyncBatchResult> syncTasks(TodoSyncBatchRequest request) async {
    return const TodoSyncBatchResult();
  }

  @override
  Future<TodoSyncProbeResult> probeHealth() async {
    if (shouldSimulateFailure()) {
      return TodoSyncProbeResult(
        endpoint: Uri.parse('http://127.0.0.1:47331/sync/health'),
        checkedAt: DateTime.utc(2026, 4, 4, 9, 30),
        statusCode: 503,
        responseBody: const <String, Object?>{
          'status': 'degraded',
          'summary':
              'Simulated relay outage · retry after disabling diagnostics failure mode.',
        },
        summary:
            'Simulated relay outage · retry after disabling diagnostics failure mode.',
      );
    }

    return TodoSyncProbeResult(
      endpoint: Uri.parse('http://127.0.0.1:47331/sync/health'),
      checkedAt: DateTime.utc(2026, 4, 4, 9, 0),
      statusCode: 200,
      responseBody: const <String, Object?>{
        'status': 'ready',
        'summary': 'Local relay healthy · pending writes 0',
      },
      summary: 'Local relay healthy · pending writes 0',
    );
  }
}
