import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_application_service_exception.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_interactive_snapshot_store.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitInteractiveSnapshotStore', () {
    test('stores and resolves a snapshot ref', () {
      final store = CockpitInteractiveSnapshotStore(
        now: _SequenceClock(<DateTime>[
          DateTime.utc(2026, 3, 30, 10, 0, 0),
          DateTime.utc(2026, 3, 30, 10, 0, 1),
        ]).call,
      );
      final snapshot = CockpitSnapshot(
        routeName: '/inbox',
        visibleTargets: <CockpitSnapshotTarget>[
          CockpitSnapshotTarget(
            registrationId: 'target-1',
            routeName: '/inbox',
            text: 'Inbox',
          ),
        ],
      );

      final ref = store.put(sessionKey: 'session-a', snapshot: snapshot);
      final stored = store.read(ref, sessionKey: 'session-a');

      expect(stored.ref, ref);
      expect(stored.sessionKey, 'session-a');
      expect(stored.snapshot, snapshot);
    });

    test('expires refs past the configured ttl', () {
      final store = CockpitInteractiveSnapshotStore(
        ttl: const Duration(seconds: 5),
        now: _SequenceClock(<DateTime>[
          DateTime.utc(2026, 3, 30, 10, 0, 0),
          DateTime.utc(2026, 3, 30, 10, 0, 7),
        ]).call,
      );

      final ref = store.put(
        sessionKey: 'session-a',
        snapshot: CockpitSnapshot(routeName: '/expired'),
      );

      expect(
        () => store.read(ref, sessionKey: 'session-a'),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'interactiveSnapshotRefExpired',
          ),
        ),
      );
    });

    test('evicts the oldest entry when capacity is exceeded', () {
      final clock = _SequenceClock(<DateTime>[
        DateTime.utc(2026, 3, 30, 10, 0, 0),
        DateTime.utc(2026, 3, 30, 10, 0, 1),
        DateTime.utc(2026, 3, 30, 10, 0, 2),
        DateTime.utc(2026, 3, 30, 10, 0, 3),
      ]);
      final store = CockpitInteractiveSnapshotStore(
        maxEntries: 2,
        now: clock.call,
      );

      final first = store.put(
        sessionKey: 'session-a',
        snapshot: CockpitSnapshot(routeName: '/first'),
      );
      final second = store.put(
        sessionKey: 'session-a',
        snapshot: CockpitSnapshot(routeName: '/second'),
      );
      final third = store.put(
        sessionKey: 'session-a',
        snapshot: CockpitSnapshot(routeName: '/third'),
      );

      expect(
        () => store.read(first, sessionKey: 'session-a'),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'interactiveSnapshotRefNotFound',
          ),
        ),
      );
      expect(store.read(second, sessionKey: 'session-a').ref, second);
      expect(store.read(third, sessionKey: 'session-a').ref, third);
    });

    test('rejects missing refs with a structured error', () {
      final store = CockpitInteractiveSnapshotStore();

      expect(
        () => store.read('missing-ref', sessionKey: 'session-a'),
        throwsA(
          isA<CockpitApplicationServiceException>().having(
            (error) => error.code,
            'code',
            'interactiveSnapshotRefNotFound',
          ),
        ),
      );
    });
  });
}

final class _SequenceClock {
  _SequenceClock(this._values);

  final List<DateTime> _values;
  var _index = 0;

  DateTime call() {
    final value = _values[_index];
    if (_index < _values.length - 1) {
      _index += 1;
    }
    return value;
  }
}
