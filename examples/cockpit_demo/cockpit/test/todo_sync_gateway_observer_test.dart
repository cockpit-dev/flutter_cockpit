import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cockpit_demo/src/network/todo_sync_gateway.dart';

void main() {
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
}
