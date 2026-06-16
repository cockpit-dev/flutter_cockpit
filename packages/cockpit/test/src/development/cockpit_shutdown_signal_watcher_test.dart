import 'dart:async';
import 'dart:io';

import 'package:cockpit/src/development/cockpit_shutdown_signal_watcher.dart';
import 'package:test/test.dart';

void main() {
  test('skips process signal watching on Windows', () async {
    final logs = <String>[];
    var watchCalled = false;

    final subscription = await cockpitWatchShutdownSignal(
      signal: ProcessSignal.sigterm,
      isWindows: true,
      writeLog: (message) async {
        logs.add(message);
      },
      stop: () async {},
      watchSignal: (_) {
        watchCalled = true;
        return const Stream<ProcessSignal>.empty();
      },
    );

    expect(subscription, isNull);
    expect(watchCalled, isFalse);
    expect(logs.single, contains('shutdown signal skipped'));
  });

  test('treats synchronous signal watch failures as non-fatal', () async {
    final logs = <String>[];

    final subscription = await cockpitWatchShutdownSignal(
      signal: ProcessSignal.sigterm,
      isWindows: false,
      writeLog: (message) async {
        logs.add(message);
      },
      stop: () async {},
      watchSignal: (_) => throw StateError('watch unavailable'),
    );

    expect(subscription, isNull);
    expect(logs.single, contains('shutdown signal unsupported'));
    expect(logs.single, contains('watch unavailable'));
  });

  test('logs asynchronous signal stream errors without crashing', () async {
    final logs = <String>[];
    final controller = StreamController<ProcessSignal>();
    addTearDown(controller.close);

    final subscription = await cockpitWatchShutdownSignal(
      signal: ProcessSignal.sigint,
      isWindows: false,
      writeLog: (message) async {
        logs.add(message);
      },
      stop: () async {},
      watchSignal: (_) => controller.stream,
    );
    addTearDown(() async => subscription?.cancel());

    controller.addError(StateError('stream failed'));
    await Future<void>.delayed(Duration.zero);

    expect(subscription, isNotNull);
    expect(logs.first, contains('shutdown signal registered'));
    expect(logs.last, contains('shutdown signal stream error'));
  });

  test('runs the stop callback when a shutdown signal is observed', () async {
    final logs = <String>[];
    final controller = StreamController<ProcessSignal>();
    addTearDown(controller.close);
    var stopCount = 0;

    final subscription = await cockpitWatchShutdownSignal(
      signal: ProcessSignal.sigterm,
      isWindows: false,
      writeLog: (message) async {
        logs.add(message);
      },
      stop: () async {
        stopCount += 1;
      },
      watchSignal: (_) => controller.stream,
    );
    addTearDown(() async => subscription?.cancel());

    controller.add(ProcessSignal.sigterm);
    await Future<void>.delayed(Duration.zero);

    expect(subscription, isNotNull);
    expect(stopCount, 1);
    expect(logs.single, contains('shutdown signal registered'));
  });
}
