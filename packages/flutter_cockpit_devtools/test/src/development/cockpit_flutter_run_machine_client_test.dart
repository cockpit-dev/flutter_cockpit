import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_status.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_supervisor_client.dart';
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

  test('machine progress and daemon log messages expose params text', () async {
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

    stdoutController
      ..add(
        '[{"event":"app.progress","params":{"message":"Building Windows application..."}}]',
      )
      ..add(
        '[{"event":"daemon.logMessage","params":{"level":"status","message":"Launching lib/main.dart on Windows..."}}]',
      );
    await Future<void>.delayed(Duration.zero);

    expect(
      events
          .where(
            (event) =>
                event.kind == CockpitFlutterRunMachineEventKind.appProgress,
          )
          .single
          .message,
      'Building Windows application...',
    );
    expect(
      events
          .where(
            (event) =>
                event.kind ==
                CockpitFlutterRunMachineEventKind.daemonLogMessage,
          )
          .single
          .message,
      'Launching lib/main.dart on Windows...',
    );
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

  test(
    'fails immediately when a request is sent after the machine exits',
    () async {
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
        await client.dispose();
      });

      stderrController.add('Lost connection to device');
      exitCode.complete(1);
      await Future<void>.delayed(Duration.zero);

      await expectLater(
        client.hotReload(appId: 'app-1'),
        throwsA(
          isA<CockpitFlutterRunMachineRequestException>().having(
            (error) => error.message,
            'message',
            contains('exitCode=1'),
          ),
        ),
      );
    },
  );

  test(
    'completes request errors when the writer throws before sending',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();

      final client = CockpitFlutterRunMachineClient(
        stdoutLines: stdoutController.stream,
        stderrLines: stderrController.stream,
        exitCode: exitCode.future,
        requestWriter: (_) async {
          throw const SocketException('stdin closed');
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

      await expectLater(
        client.stop(appId: 'app-1'),
        throwsA(isA<SocketException>()),
      );
    },
  );

  test(
    'development supervisor exposes flutter run launch failures through the control plane',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit-development-supervisor-bin-',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final logFile = File(p.join(tempDir.path, 'supervisor.log'));
      final packageRoot = await _resolveDevtoolsPackageRoot();
      final supervisorScript = File(
        p.join(
          packageRoot,
          'bin',
          'flutter_cockpit_development_supervisor.dart',
        ),
      );
      final sessionPort = await _allocateLoopbackPort();
      final supervisorPort = await _allocateLoopbackPort();

      Process? process;
      addTearDown(() async {
        final running = process;
        if (running == null) {
          return;
        }
        running.kill(ProcessSignal.sigterm);
        try {
          await running.exitCode.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          running.kill(ProcessSignal.sigkill);
          await running.exitCode.timeout(const Duration(seconds: 2));
        }
      });

      process = await Process.start(Platform.resolvedExecutable, <String>[
        'run',
        supervisorScript.path,
        '--project-dir',
        packageRoot,
        '--target',
        'lib/flutter_cockpit_devtools.dart',
        '--platform',
        'windows',
        '--device-id',
        'windows',
        '--session-port',
        '$sessionPort',
        '--app-host-port',
        '$sessionPort',
        '--supervisor-port',
        '$supervisorPort',
        '--flutter-executable',
        p.join(tempDir.path, 'missing-flutter'),
        '--log-file',
        logFile.path,
        '--flutter-version',
        '3.32.0',
        '--launch-timeout-seconds',
        '1',
      ], workingDirectory: packageRoot);
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());

      final baseUri = Uri(
        scheme: 'http',
        host: '127.0.0.1',
        port: supervisorPort,
      );
      final response = await _waitForSupervisorFailure(baseUri);
      expect(response.status.state, CockpitDevelopmentSessionState.failed);
      expect(response.status.lastError, contains('missing-flutter'));

      final logText = await logFile.readAsString();
      expect(logText, contains('development machine launch start'));
      expect(logText, contains('development machine launch failed'));
      expect(logText, contains('missing-flutter'));

      final stopped = await CockpitDevelopmentSessionSupervisorClient().stop(
        baseUri,
      );
      expect(stopped.status.state, CockpitDevelopmentSessionState.stopped);
    },
  );
}

Future<int> _allocateLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  try {
    return socket.port;
  } finally {
    await socket.close();
  }
}

Future<String> _resolveDevtoolsPackageRoot() async {
  final packageLibUri = await Isolate.resolvePackageUri(
    Uri.parse('package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart'),
  );
  if (packageLibUri == null) {
    throw StateError('Unable to resolve flutter_cockpit_devtools package URI.');
  }
  return p.normalize(p.join(p.dirname(p.fromUri(packageLibUri)), '..'));
}

Future<CockpitDevelopmentSessionSupervisorResponse> _waitForSupervisorFailure(
  Uri baseUri,
) async {
  final client = CockpitDevelopmentSessionSupervisorClient(
    requestTimeout: const Duration(seconds: 2),
  );
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  Object? lastFailure;
  while (DateTime.now().isBefore(deadline)) {
    try {
      final response = await client.readStatus(baseUri);
      if (response.status.state == CockpitDevelopmentSessionState.failed) {
        return response;
      }
    } on Object catch (error) {
      lastFailure = error;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TimeoutException(
    'Development supervisor did not report failed startup: $lastFailure',
  );
}
