import 'dart:async';

import 'package:cockpit/src/application/cockpit_interactive_session_lock.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitInteractiveSessionLock', () {
    test('serializes work for the same session', () async {
      final lock = CockpitInteractiveSessionLock();
      final gate = Completer<void>();
      final order = <String>[];

      final first = lock.run('session-a', () async {
        order.add('first-start');
        await gate.future;
        order.add('first-end');
      });
      final second = lock.run('session-a', () async {
        order.add('second-start');
        order.add('second-end');
      });

      await Future<void>.delayed(Duration.zero);
      expect(order, <String>['first-start']);

      gate.complete();
      await Future.wait<void>(<Future<void>>[first, second]);

      expect(order, <String>[
        'first-start',
        'first-end',
        'second-start',
        'second-end',
      ]);
    });

    test('allows different sessions to proceed independently', () async {
      final lock = CockpitInteractiveSessionLock();
      final firstStarted = Completer<void>();
      final allowFirstToFinish = Completer<void>();
      final secondCompleted = Completer<void>();

      final first = lock.run('session-a', () async {
        firstStarted.complete();
        await allowFirstToFinish.future;
      });
      final second = lock.run('session-b', () async {
        secondCompleted.complete();
      });

      await firstStarted.future;
      await secondCompleted.future.timeout(const Duration(seconds: 1));

      allowFirstToFinish.complete();
      await Future.wait<void>(<Future<void>>[first, second]);
    });
  });
}
