import 'dart:async';

import 'package:flutter_cockpit_devtools/src/development/cockpit_flutter_run_machine_client.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_flutter_run_machine_event.dart';
import 'package:test/test.dart';

void main() {
  test(
    'machine output lines map to typed events and capture VM service URI',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      final writes = <String>[];

      final client = CockpitFlutterRunMachineClient(
        stdoutLines: stdoutController.stream,
        stderrLines: stderrController.stream,
        exitCode: exitCode.future,
        requestWriter: (payload) async {
          writes.add(payload);
        },
      );
      addTearDown(() async {
        await stdoutController.close();
        await stderrController.close();
        if (!exitCode.isCompleted) {
          exitCode.complete(0);
        }
        await client.dispose();
      });

      final events = <CockpitFlutterRunMachineEvent>[];
      final subscription = client.events.listen(events.add);
      addTearDown(subscription.cancel);

      stdoutController
        ..add('[{"event":"daemon.connected","params":{"pid":123}}]')
        ..add('[{"event":"app.start","params":{"appId":"app-1"}}]')
        ..add(
          '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:34567/abcd/ws"}}]',
        );

      await Future<void>.delayed(Duration.zero);

      expect(
        events.map((event) => event.kind),
        containsAll(<Object?>[
          CockpitFlutterRunMachineEventKind.daemonConnected,
          CockpitFlutterRunMachineEventKind.appStart,
          CockpitFlutterRunMachineEventKind.appDebugPort,
        ]),
      );
      expect(client.currentAppId, 'app-1');
      expect(
        await client.vmServiceUri,
        Uri.parse('ws://127.0.0.1:34567/abcd/ws'),
      );
      expect(writes, isEmpty);
    },
  );

  test('hot reload success and failure are distinguishable', () async {
    final stdoutController = StreamController<String>();
    final stderrController = StreamController<String>();
    final exitCode = Completer<int>();
    final writes = <String>[];

    final client = CockpitFlutterRunMachineClient(
      stdoutLines: stdoutController.stream,
      stderrLines: stderrController.stream,
      exitCode: exitCode.future,
      requestWriter: (payload) async {
        writes.add(payload);
      },
    );
    addTearDown(() async {
      await stdoutController.close();
      await stderrController.close();
      if (!exitCode.isCompleted) {
        exitCode.complete(0);
      }
      await client.dispose();
    });

    final successFuture = client.hotReload(appId: 'app-1');
    await Future<void>.delayed(Duration.zero);
    expect(writes.single, contains('"method":"app.restart"'));
    expect(writes.single, contains('"fullRestart":false'));
    stdoutController.add('[{"id":0,"result":{"code":0,"message":"ok"}}]');
    final successResult = await successFuture;
    expect(successResult, <String, Object?>{'code': 0, 'message': 'ok'});

    final failureFuture = client.hotRestart(appId: 'app-1');
    await Future<void>.delayed(Duration.zero);
    stdoutController.add('[{"id":1,"error":"hot restart failed"}]');
    await expectLater(
      failureFuture,
      throwsA(
        isA<CockpitFlutterRunMachineRequestException>().having(
          (error) => error.message,
          'message',
          contains('hot restart failed'),
        ),
      ),
    );
  });

  test('stderr and exit become structured events', () async {
    final stdoutController = StreamController<String>();
    final stderrController = StreamController<String>();
    final exitCode = Completer<int>();

    final client = CockpitFlutterRunMachineClient(
      stdoutLines: stdoutController.stream,
      stderrLines: stderrController.stream,
      exitCode: exitCode.future,
      requestWriter: (_) async {},
    );
    addTearDown(() async {
      await stdoutController.close();
      await stderrController.close();
      if (!exitCode.isCompleted) {
        exitCode.complete(0);
      }
      await client.dispose();
    });

    final events = <CockpitFlutterRunMachineEvent>[];
    final subscription = client.events.listen(events.add);
    addTearDown(subscription.cancel);

    stderrController.add('Lost connection to device');
    exitCode.complete(1);
    await Future<void>.delayed(Duration.zero);

    expect(
      events.map((event) => event.kind),
      containsAll(<Object?>[
        CockpitFlutterRunMachineEventKind.stderr,
        CockpitFlutterRunMachineEventKind.processExit,
      ]),
    );
    expect(events.last.exitCode, 1);
  });

  test('dispose runs the owned process shutdown hook', () async {
    final stdoutController = StreamController<String>();
    final stderrController = StreamController<String>();
    final exitCode = Completer<int>();
    var disposeCalled = 0;

    final client = CockpitFlutterRunMachineClient(
      stdoutLines: stdoutController.stream,
      stderrLines: stderrController.stream,
      exitCode: exitCode.future,
      requestWriter: (_) async {},
      closeProcess: () async {
        disposeCalled += 1;
      },
    );

    await stdoutController.close();
    await stderrController.close();
    exitCode.complete(0);
    await client.dispose();

    expect(disposeCalled, 1);
  });

  test('dispose does not hang on a stuck shutdown hook', () async {
    final stdoutController = StreamController<String>();
    final stderrController = StreamController<String>();
    final exitCode = Completer<int>();

    final client = CockpitFlutterRunMachineClient(
      stdoutLines: stdoutController.stream,
      stderrLines: stderrController.stream,
      exitCode: exitCode.future,
      requestWriter: (_) async {},
      closeProcess: () => Completer<void>().future,
    );

    await stdoutController.close();
    await stderrController.close();
    exitCode.complete(0);

    final stopwatch = Stopwatch()..start();
    await client.dispose();
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
