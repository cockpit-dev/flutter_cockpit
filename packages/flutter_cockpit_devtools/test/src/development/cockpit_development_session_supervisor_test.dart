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
      expect(remoteChecks, 1);
      expect(uiIdleChecks, 1);
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
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
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(harness.closeProcessCallCount, 1);
      expect(
        harness.stoppedAppIds,
        contains(harness.handle.remoteSessionHandle?.appId),
      );
    },
  );
}

final class _MachineHarness {
  _MachineHarness()
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
          remoteSessionHandle: CockpitRemoteSessionHandle(
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
