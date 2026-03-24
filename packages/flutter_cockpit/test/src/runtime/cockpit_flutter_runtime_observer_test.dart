import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_cockpit/flutter_cockpit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('captures framework errors, uncaught errors, and debug logs', () {
    final seenLogs = <String?>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      seenLogs.add(message);
    };

    final criticalEvents = <CockpitRuntimeEvent>[];
    final observer = CockpitFlutterRuntimeObserver(
      routeNameProvider: () => '/debug',
      onCriticalEvent: criticalEvents.add,
      maxStackTraceLines: 1,
    );
    addTearDown(() {
      observer.dispose();
      debugPrint = previousDebugPrint;
    });

    observer.recordDebugLog('sync started');
    observer.recordUnhandledError(
      StateError('boom'),
      StackTrace.fromString('#0 a\n#1 b'),
    );
    observer.recordFlutterFrameworkError(
      FlutterErrorDetails(
        exception: ArgumentError('bad'),
        stack: StackTrace.fromString('#0 c\n#1 d'),
        library: 'widgets',
      ),
    );

    final all = observer.snapshot(maxEntries: 10);
    final errorsOnly = observer.snapshot(
      maxEntries: 10,
      query: const CockpitRuntimeQuery(onlyErrors: true),
    );

    expect(all.totalEntryCount, 3);
    expect(all.errorCount, 2);
    expect(all.warningCount, 0);
    expect(all.entries.last.routeName, '/debug');
    expect(errorsOnly.totalEntryCount, 2);
    expect(criticalEvents, hasLength(2));
    expect(criticalEvents.every((event) => event.stackTraceTruncated), isTrue);

    debugPrint('forwarded log');
    expect(seenLogs, contains('forwarded log'));
  });

  test('captures plain print output through the diagnostics zone', () async {
    final forwardedPrints = <String>[];
    final observer = CockpitFlutterRuntimeObserver(
      routeNameProvider: () => '/zone',
      captureDebugPrint: false,
    );
    addTearDown(observer.dispose);

    await runZoned(
      () async {
        observer.runWithDiagnosticsZone(() {
          print('plain zone log');
        });
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          forwardedPrints.add(line);
        },
      ),
    );

    final snapshot = observer.snapshot(maxEntries: 10);

    expect(
      snapshot.entries.any((entry) => entry.message.contains('plain zone log')),
      isTrue,
    );
    expect(forwardedPrints, contains('plain zone log'));
  });
}
