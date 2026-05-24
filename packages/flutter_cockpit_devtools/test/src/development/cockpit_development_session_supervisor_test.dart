import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_handle.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_status.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_supervisor.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_supervisor_client.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_flutter_run_machine_client.dart';
import 'package:flutter_cockpit_devtools/src/session/cockpit_remote_session_handle.dart';
import 'package:test/test.dart';

void main() {
  test(
    'supervisor exposes a starting control plane before remote launch completes',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      var connectorCalls = 0;
      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle.copyWith(
          appId: '',
          remoteSessionHandle: null,
        ),
        machineClient: null,
        machineClientConnector: () async {
          connectorCalls += 1;
          return harness.client;
        },
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => true,
        now: () => DateTime.utc(2026, 3, 23, 2, 30),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final healthRequest = await client.getUrl(
        (await supervisor.currentHandle()).supervisorBaseUri.resolve('/health'),
      );
      final healthResponse = await healthRequest.close();
      final healthPayload =
          jsonDecode(await utf8.decoder.bind(healthResponse).join())
              as Map<String, Object?>;
      expect(
        healthPayload['state'],
        CockpitDevelopmentSessionState.starting.jsonValue,
      );
      expect(connectorCalls, 0);

      await supervisor.bindRemoteSession(harness.handle.remoteSessionHandle!);
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      expect(connectorCalls, 1);
      final currentHandle = await supervisor.currentHandle();
      expect(currentHandle.appId, '');
      expect(
        currentHandle.remoteSessionHandle?.baseUrl,
        harness.handle.remoteSessionHandle?.baseUrl,
      );
    },
  );

  test(
    'supervisor clears stale lastError after bind and ready recovery',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle.copyWith(
          appId: '',
          remoteSessionHandle: null,
        ),
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => true,
        now: () => DateTime.utc(2026, 3, 23, 2, 30),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      supervisor.reportStartupFailure(StateError('stale startup failure'));

      final failedStatus = await supervisor.currentStatus();
      expect(failedStatus.state, CockpitDevelopmentSessionState.failed);
      expect(failedStatus.lastError, contains('stale startup failure'));

      await supervisor.bindRemoteSession(harness.handle.remoteSessionHandle!);
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      final recoveredStatus = await supervisor.currentStatus();
      expect(recoveredStatus.state, CockpitDevelopmentSessionState.ready);
      expect(recoveredStatus.lastError, isNull);
    },
  );

  test(
    'supervisor does not settle startup from machine app events before remote session is bound',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      var remoteChecks = 0;
      var uiIdleChecks = 0;
      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle.copyWith(
          appId: '',
          remoteSessionHandle: null,
        ),
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async {
          remoteChecks += 1;
          return true;
        },
        uiIdleWaiter: (_) async {
          uiIdleChecks += 1;
          return true;
        },
        now: () => DateTime.utc(2026, 3, 23, 2, 30),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"app-1"}}]',
      );
      harness.stdoutController.add('[{"event":"app.started","params":{}}]');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final pendingStatus = await supervisor.currentStatus();
      expect(pendingStatus.state, CockpitDevelopmentSessionState.starting);
      expect(remoteChecks, 0);
      expect(uiIdleChecks, 0);

      await supervisor.bindRemoteSession(harness.handle.remoteSessionHandle!);
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      expect(remoteChecks, greaterThanOrEqualTo(1));
      expect(uiIdleChecks, greaterThanOrEqualTo(1));
    },
  );

  test(
    'supervisor transitions to ready only after remote recovery and UI idle',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      var remoteChecks = 0;
      var uiIdleChecks = 0;
      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async {
          remoteChecks += 1;
          return true;
        },
        uiIdleWaiter: (_) async {
          uiIdleChecks += 1;
          return true;
        },
        now: () => DateTime.utc(2026, 3, 23, 3),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      expect(
        (await supervisor.currentStatus()).state,
        CockpitDevelopmentSessionState.starting,
      );

      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"app-1"}}]',
      );
      harness.stdoutController.add('[{"event":"app.started","params":{}}]');
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      final status = await supervisor.currentStatus();
      expect(status.state, CockpitDevelopmentSessionState.ready);
      expect(status.appReachable, isTrue);
      expect(status.remoteSessionReachable, isTrue);
      expect(remoteChecks, greaterThanOrEqualTo(1));
      expect(uiIdleChecks, greaterThanOrEqualTo(1));
    },
  );

  test(
    'supervisor can settle to ready from app.start when app.started is absent',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      var remoteChecks = 0;
      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async {
          remoteChecks += 1;
          return remoteChecks >= 2;
        },
        uiIdleWaiter: (_) async => true,
        now: () => DateTime.utc(2026, 3, 23, 3),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"app-1"}}]',
      );

      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      final status = await supervisor.currentStatus();
      expect(status.state, CockpitDevelopmentSessionState.ready);
      expect(status.appReachable, isTrue);
      expect(status.remoteSessionReachable, isTrue);
      expect(remoteChecks, greaterThanOrEqualTo(2));
    },
  );

  test(
    'supervisor keeps polling after app.started until remote session becomes ready',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      var remoteChecks = 0;
      var uiIdleChecks = 0;
      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async {
          remoteChecks += 1;
          return remoteChecks >= 3;
        },
        uiIdleWaiter: (_) async {
          uiIdleChecks += 1;
          return uiIdleChecks >= 2;
        },
        now: () => DateTime.utc(2026, 3, 23, 3),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"app-1"}}]',
      );
      harness.stdoutController.add('[{"event":"app.started","params":{}}]');

      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      final status = await supervisor.currentStatus();
      expect(status.state, CockpitDevelopmentSessionState.ready);
      expect(remoteChecks, greaterThanOrEqualTo(3));
      expect(uiIdleChecks, greaterThanOrEqualTo(2));
    },
  );

  test(
    'supervisor can become ready before attach and lazily connect on reload',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      var connectorCalls = 0;
      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: null,
        machineClientConnector: () async {
          connectorCalls += 1;
          return harness.client;
        },
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => true,
        now: () => DateTime.utc(2026, 3, 23, 3),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      final reloadFuture = supervisor.reload(
        CockpitDevelopmentReloadMode.hotReload,
      );
      await Future<void>.delayed(Duration.zero);
      expect(connectorCalls, 1);
      expect(harness.writes.last, contains('"fullRestart":false'));
      harness.stdoutController.add('[{"id":0,"result":{"code":0}}]');
      final reloadedStatus = await reloadFuture;

      expect(reloadedStatus.state, CockpitDevelopmentSessionState.ready);
      expect(
        reloadedStatus.lastReloadMode,
        CockpitDevelopmentReloadMode.hotReload,
      );
    },
  );

  test('hot reload waits for UI idle before reporting ready', () async {
    final harness = _MachineHarness();
    addTearDown(harness.dispose);

    var now = DateTime.utc(2026, 3, 23, 3);
    var uiIdleRecovered = true;

    final supervisor = CockpitDevelopmentSessionSupervisor(
      initialHandle: harness.handle,
      machineClient: harness.client,
      remoteReachabilityProbe: (_) async => true,
      uiIdleWaiter: (_) async => uiIdleRecovered,
      now: () {
        final current = now;
        now = now.add(const Duration(milliseconds: 250));
        return current;
      },
      settleTimeout: const Duration(seconds: 2),
      settlePollInterval: const Duration(milliseconds: 10),
    );
    addTearDown(supervisor.dispose);

    await supervisor.start();
    harness.stdoutController.add(
      '[{"event":"app.start","params":{"appId":"app-1"}}]',
    );
    harness.stdoutController.add('[{"event":"app.started","params":{}}]');
    await supervisor.bindRemoteSession(harness.handle.remoteSessionHandle!);
    await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

    uiIdleRecovered = false;
    final reloadFuture = supervisor.reload(
      CockpitDevelopmentReloadMode.hotReload,
    );
    await Future<void>.delayed(Duration.zero);
    expect(harness.writes.last, contains('"fullRestart":false'));
    harness.stdoutController.add('[{"id":0,"result":{"code":0}}]');

    await expectLater(reloadFuture, throwsA(isA<StateError>()));
    final failedStatus = await supervisor.currentStatus();
    expect(failedStatus.state, CockpitDevelopmentSessionState.failed);
    expect(failedStatus.lastReloadSucceeded, isFalse);
    expect(failedStatus.lastReloadMode, CockpitDevelopmentReloadMode.hotReload);
  });

  test(
    'startup still requires ui idle recovery before becoming ready',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      var now = DateTime.utc(2026, 3, 23, 3);
      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => false,
        now: () {
          final current = now;
          now = now.add(const Duration(milliseconds: 250));
          return current;
        },
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"app-1"}}]',
      );
      harness.stdoutController.add('[{"event":"app.started","params":{}}]');

      await supervisor.waitForState(CockpitDevelopmentSessionState.failed);

      final status = await supervisor.currentStatus();
      expect(status.state, CockpitDevelopmentSessionState.failed);
      expect(
        status.lastError,
        'Remote session did not recover to an idle ready state.',
      );
    },
  );

  test(
    'hot restart requires ui idle recovery before reporting ready',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      var now = DateTime.utc(2026, 3, 23, 3);
      var uiIdleRecovered = true;
      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => uiIdleRecovered,
        now: () {
          final current = now;
          now = now.add(const Duration(milliseconds: 250));
          return current;
        },
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"app-1"}}]',
      );
      harness.stdoutController.add('[{"event":"app.started","params":{}}]');
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      uiIdleRecovered = false;
      final reloadFuture = supervisor.reload(
        CockpitDevelopmentReloadMode.hotRestart,
      );
      await Future<void>.delayed(Duration.zero);
      expect(harness.writes.last, contains('"fullRestart":true'));
      harness.stdoutController.add('[{"id":0,"result":{"code":0}}]');

      await expectLater(reloadFuture, throwsA(isA<StateError>()));
      final status = await supervisor.currentStatus();
      expect(status.state, CockpitDevelopmentSessionState.failed);
      expect(status.lastReloadSucceeded, isFalse);
      expect(status.lastReloadMode, CockpitDevelopmentReloadMode.hotRestart);
      expect(status.lastError, contains('idle ready state'));
    },
  );

  test('settle recovery caps a single blocked probe attempt', () async {
    final harness = _MachineHarness();
    addTearDown(harness.dispose);

    var now = DateTime.utc(2026, 3, 23, 3);
    var uiIdleAttempts = 0;
    final firstBlockedAttempt = Completer<bool>();
    final supervisor = CockpitDevelopmentSessionSupervisor(
      initialHandle: harness.handle,
      machineClient: harness.client,
      remoteReachabilityProbe: (_) async => true,
      uiIdleWaiter: (_) {
        uiIdleAttempts += 1;
        if (uiIdleAttempts == 1) {
          return firstBlockedAttempt.future;
        }
        return Future<bool>.value(true);
      },
      now: () {
        final current = now;
        now = now.add(const Duration(milliseconds: 250));
        return current;
      },
      settleTimeout: const Duration(seconds: 2),
      settlePollInterval: const Duration(milliseconds: 10),
      settleProbeTimeout: const Duration(milliseconds: 25),
    );
    addTearDown(supervisor.dispose);

    await supervisor.start();
    harness.stdoutController.add(
      '[{"event":"app.start","params":{"appId":"app-1"}}]',
    );
    harness.stdoutController.add('[{"event":"app.started","params":{}}]');

    await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

    expect(uiIdleAttempts, greaterThanOrEqualTo(2));
    expect(firstBlockedAttempt.isCompleted, isFalse);
  });

  test(
    'supervisor syncs cached machine app state when the machine client emitted before subscription',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"machine-app-early"}}]',
      );
      harness.stdoutController.add(
        '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:34567/early/ws"}}]',
      );
      await Future<void>.delayed(Duration.zero);

      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle.copyWith(appId: '', vmServiceUri: null),
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => true,
        now: () => DateTime.utc(2026, 3, 23, 4),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();

      final currentHandle = await supervisor.currentHandle();
      expect(currentHandle.appId, 'machine-app-early');
      expect(
        currentHandle.vmServiceUri,
        Uri.parse('ws://127.0.0.1:34567/early/ws'),
      );
    },
  );

  test(
    'reload updates generation and stop shuts down the control plane',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => true,
        appStopper: (appId) async {
          harness.stoppedAppIds.add(appId);
        },
        now: () => DateTime.utc(2026, 3, 23, 4),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"app-1"}}]',
      );
      harness.stdoutController.add('[{"event":"app.started","params":{}}]');
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      final beforeReload = await supervisor.currentHandle();
      final reloadFuture = supervisor.reload(
        CockpitDevelopmentReloadMode.hotRestart,
      );
      await Future<void>.delayed(Duration.zero);
      expect(harness.writes.last, contains('"fullRestart":true'));
      harness.stdoutController.add('[{"id":0,"result":{"code":0}}]');
      final reloadedStatus = await reloadFuture;

      expect(reloadedStatus.state, CockpitDevelopmentSessionState.ready);
      expect(
        reloadedStatus.lastReloadMode,
        CockpitDevelopmentReloadMode.hotRestart,
      );
      expect(
        reloadedStatus.reloadGeneration,
        beforeReload.reloadGeneration + 1,
      );

      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final healthRequest = await client.getUrl(
        (await supervisor.currentHandle()).supervisorBaseUri.resolve('/health'),
      );
      final healthResponse = await healthRequest.close();
      final healthPayload =
          jsonDecode(await utf8.decoder.bind(healthResponse).join())
              as Map<String, Object?>;
      expect(
        healthPayload['state'],
        CockpitDevelopmentSessionState.ready.jsonValue,
      );

      await supervisor.stop();
      expect(
        (await supervisor.currentStatus()).state,
        CockpitDevelopmentSessionState.stopped,
      );
      expect(
        harness.writes.any(
          (payload) => payload.contains('"method":"app.stop"'),
        ),
        isTrue,
      );
      await supervisor.done;
      expect(harness.closeProcessCallCount, 1);
      expect(
        harness.stoppedAppIds,
        contains(harness.handle.remoteSessionHandle?.appId),
      );
    },
  );

  test(
    'supervisor stop endpoint returns a stopped payload before closing',
    () async {
      final harness = _MachineHarness();
      addTearDown(harness.dispose);

      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => true,
        appStopper: (appId) async {
          harness.stoppedAppIds.add(appId);
        },
        now: () => DateTime.utc(2026, 3, 23, 5),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      harness.stdoutController.add(
        '[{"event":"app.start","params":{"appId":"app-1"}}]',
      );
      harness.stdoutController.add('[{"event":"app.started","params":{}}]');
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      final client = CockpitDevelopmentSessionSupervisorClient();
      final response = await client.stop(
        (await supervisor.currentHandle()).supervisorBaseUri,
      );

      expect(response.status.state, CockpitDevelopmentSessionState.stopped);
      expect(
        harness.writes.any(
          (payload) => payload.contains('"method":"app.stop"'),
        ),
        isTrue,
      );
      await supervisor.done;
      expect(harness.closeProcessCallCount, 1);
      expect(
        harness.stoppedAppIds,
        contains(harness.handle.remoteSessionHandle?.appId),
      );
    },
  );

  test(
    'supervisor does not call the platform stopper when the remote platform app id is unknown',
    () async {
      final harness = _MachineHarness(
        remoteSessionHandle: CockpitRemoteSessionHandle(
          platform: 'ios',
          deviceId: '00008110-0009341C2EF3801E',
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'lib/main.dart',
          appId: 'remote-session-1',
          platformAppIdKnown: false,
          host: 'fd69:8f18:f0a9::1',
          hostPort: 57331,
          devicePort: 57331,
          baseUrl: 'http://[fd69:8f18:f0a9::1]:57331',
          launchedAt: DateTime.utc(2026, 3, 23, 0, 0),
        ),
      );
      addTearDown(harness.dispose);

      final supervisor = CockpitDevelopmentSessionSupervisor(
        initialHandle: harness.handle,
        machineClient: harness.client,
        remoteReachabilityProbe: (_) async => true,
        uiIdleWaiter: (_) async => true,
        appStopper: (appId) async {
          harness.stoppedAppIds.add(appId);
        },
        now: () => DateTime.utc(2026, 3, 23, 5),
        settleTimeout: const Duration(seconds: 2),
        settlePollInterval: const Duration(milliseconds: 10),
      );
      addTearDown(supervisor.dispose);

      await supervisor.start();
      await supervisor.waitForState(CockpitDevelopmentSessionState.ready);

      await supervisor.stop();

      expect(harness.stoppedAppIds, isEmpty);
    },
  );
}

final class _MachineHarness {
  _MachineHarness({CockpitRemoteSessionHandle? remoteSessionHandle})
    : stdoutController = StreamController<String>(),
      stderrController = StreamController<String>(),
      exitCode = Completer<int>(),
      writes = <String>[],
      handle = CockpitDevelopmentSessionHandle(
        developmentSessionId: 'dev-session-1',
        platform: 'android',
        deviceId: 'emulator-5554',
        projectDir: '/workspace/examples/cockpit_demo',
        target: 'lib/main.dart',
        appId: 'dev.cockpit.cockpit_demo',
        appBaseUrl: 'http://127.0.0.1:57331',
        supervisorBaseUrl: 'http://127.0.0.1:0',
        launchedAt: DateTime.utc(2026, 3, 23, 0, 0),
        reloadGeneration: 1,
        remoteSessionHandle:
            remoteSessionHandle ??
            CockpitRemoteSessionHandle(
              platform: 'android',
              deviceId: 'emulator-5554',
              projectDir: '/workspace/examples/cockpit_demo',
              target: 'lib/main.dart',
              appId: 'dev.cockpit.cockpit_demo',
              host: '127.0.0.1',
              hostPort: 57331,
              devicePort: 47331,
              baseUrl: 'http://127.0.0.1:57331',
              launchedAt: DateTime.utc(2026, 3, 23, 0, 0),
            ),
      ) {
    client = CockpitFlutterRunMachineClient(
      stdoutLines: stdoutController.stream,
      stderrLines: stderrController.stream,
      exitCode: exitCode.future,
      requestWriter: (payload) async {
        writes.add(payload);
      },
      closeProcess: () async {
        closeProcessCallCount += 1;
      },
    );
  }

  final StreamController<String> stdoutController;
  final StreamController<String> stderrController;
  final Completer<int> exitCode;
  final List<String> writes;
  final CockpitDevelopmentSessionHandle handle;
  int closeProcessCallCount = 0;
  final List<String> stoppedAppIds = <String>[];
  late final CockpitFlutterRunMachineClient client;

  Future<void> dispose() async {
    await stdoutController.close();
    await stderrController.close();
    if (!exitCode.isCompleted) {
      exitCode.complete(0);
    }
    await client.dispose();
  }
}
