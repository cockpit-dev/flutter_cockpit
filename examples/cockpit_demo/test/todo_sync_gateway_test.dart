import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/network/todo_sync_gateway.dart';

void main() {
  test('TodoLoopbackSyncGateway serves a real loopback health probe', () async {
    final gateway = TodoLoopbackSyncGateway(
      payloadBuilder: () async => <String, Object?>{
        'status': 'ready',
        'summary': 'Local relay healthy · pending writes 0',
      },
    );
    addTearDown(gateway.close);

    final result = await gateway.probeHealth();

    expect(result.statusCode, 200);
    expect(result.endpoint.path, '/sync/health');
    expect(result.responseBody['status'], 'ready');
    expect(result.summary, contains('pending writes 0'));
  });

  test(
    'TodoLoopbackSyncGateway traffic is observable through CockpitHttpNetworkObserver',
    () async {
      final gateway = TodoLoopbackSyncGateway(
        payloadBuilder: () async => <String, Object?>{
          'status': 'ready',
          'summary': 'Local relay healthy · pending writes 0',
        },
      );
      final observer = CockpitHttpNetworkObserver(maxRetainedEntries: 8);
      final previousOverrides = HttpOverrides.current;
      observer.attachParentOverrides(previousOverrides);
      HttpOverrides.global = observer;
      addTearDown(() async {
        HttpOverrides.global = previousOverrides;
        await gateway.close();
      });

      await gateway.probeHealth();
      final snapshot = observer.snapshot(maxEntries: 4);

      expect(snapshot.entries, isNotEmpty);
      expect(snapshot.entries.single.uri, contains('/sync/health'));
      expect(snapshot.entries.single.statusCode, 200);
    },
  );

  test(
    'TodoLoopbackSyncGateway can simulate a degraded relay response for validation flows',
    () async {
      var simulateFailure = true;
      final gateway = TodoLoopbackSyncGateway(
        payloadBuilder: () async => <String, Object?>{
          'status': 'ready',
          'summary': 'Local relay healthy · pending writes 0',
        },
        shouldSimulateFailure: () => simulateFailure,
      );
      addTearDown(gateway.close);

      final result = await gateway.probeHealth();

      expect(result.statusCode, 503);
      expect(result.endpoint.path, '/sync/health');
      expect(result.responseBody['status'], 'degraded');
      expect(result.summary, contains('Simulated relay outage'));
      simulateFailure = false;
    },
  );
}
