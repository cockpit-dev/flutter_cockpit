import 'dart:async';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_development_session_machine_launcher.dart';
import 'package:flutter_cockpit_devtools/src/development/cockpit_flutter_run_machine_client.dart';
import 'package:flutter_cockpit_devtools/src/remote/cockpit_android_port_forwarder.dart';
import 'package:test/test.dart';

void main() {
  test(
    'launch starts flutter run with remote session defines and returns the machine app id',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      final capturedStarts = <Map<String, Object?>>[];

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter: ({
          required projectDir,
          required target,
          required deviceId,
          flutterExecutable,
          extraArgs = const <String>[],
        }) async {
          capturedStarts.add(<String, Object?>{
            'projectDir': projectDir,
            'target': target,
            'deviceId': deviceId,
            'flutterExecutable': flutterExecutable,
            'extraArgs': extraArgs,
          });
          final client = CockpitFlutterRunMachineClient(
            stdoutLines: stdoutController.stream,
            stderrLines: stderrController.stream,
            exitCode: exitCode.future,
            requestWriter: (_) async {},
          );
          stdoutController.add(
            '[{"event":"app.start","params":{"appId":"machine-app-1"}}]',
          );
          stdoutController.add(
            '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:34567/abcd/ws"}}]',
          );
          return client;
        },
        statusReader: (_) async => _readyStatus('android'),
        portForwarder: const _RecordingPortForwarder(58331),
        now: () => DateTime.utc(2026, 4, 4, 15),
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentMachineSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'android',
          deviceId: 'emulator-5554',
          sessionPort: 47331,
          hostPort: 57331,
          launchTimeout: Duration(seconds: 10),
          flutterVersion: '3.39.0',
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
      );

      expect(capturedStarts, hasLength(1));
      expect(
        capturedStarts.single['extraArgs'],
        <String>[
          '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
          '--dart-define=FLUTTER_PILOT_REMOTE_HOST=127.0.0.1',
          '--dart-define=FLUTTER_PILOT_REMOTE_PORT=47331',
          '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=3.39.0',
        ],
      );
      expect(result.remoteSessionHandle.appId, 'machine-app-1');
      expect(result.remoteSessionHandle.hostPort, 58331);
      expect(
        result.machineClient.currentVmServiceUri,
        Uri.parse('ws://127.0.0.1:34567/abcd/ws'),
      );

      await stdoutController.close();
      await stderrController.close();
      exitCode.complete(0);
      await result.machineClient.dispose();
    },
  );

  test(
    'ios development launch binds the remote session to a host-reachable address',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      final capturedStarts = <Map<String, Object?>>[];

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter: ({
          required projectDir,
          required target,
          required deviceId,
          flutterExecutable,
          extraArgs = const <String>[],
        }) async {
          capturedStarts.add(<String, Object?>{
            'projectDir': projectDir,
            'target': target,
            'deviceId': deviceId,
            'flutterExecutable': flutterExecutable,
            'extraArgs': extraArgs,
          });
          final client = CockpitFlutterRunMachineClient(
            stdoutLines: stdoutController.stream,
            stderrLines: stderrController.stream,
            exitCode: exitCode.future,
            requestWriter: (_) async {},
          );
          stdoutController.add(
            '[{"event":"app.start","params":{"appId":"machine-ios-app"}}]',
          );
          stdoutController.add(
            '[{"event":"app.debugPort","params":{"wsUri":"ws://127.0.0.1:35567/ios/ws"}}]',
          );
          return client;
        },
        statusReader: (_) async => _readyStatus('ios'),
        now: () => DateTime.utc(2026, 4, 4, 16),
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentMachineSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'ios',
          deviceId: 'FC5B7D0F-B7FB-4A7A-B1B0-FF28BC289BC2',
          sessionPort: 47331,
          hostPort: 57331,
          launchTimeout: Duration(seconds: 10),
          flutterVersion: '3.39.0',
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
      );

      expect(capturedStarts, hasLength(1));
      expect(
        capturedStarts.single['extraArgs'],
        <String>[
          '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
          '--dart-define=FLUTTER_PILOT_REMOTE_HOST=0.0.0.0',
          '--dart-define=FLUTTER_PILOT_REMOTE_PORT=47331',
          '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=3.39.0',
        ],
      );
      expect(result.remoteSessionHandle.appId, 'machine-ios-app');
      expect(result.remoteSessionHandle.hostPort, 57331);

      await stdoutController.close();
      await stderrController.close();
      exitCode.complete(0);
      await result.machineClient.dispose();
    },
  );

  test(
    'web development launch uses localhost for browser-facing health probes',
    () async {
      final stdoutController = StreamController<String>();
      final stderrController = StreamController<String>();
      final exitCode = Completer<int>();
      final capturedStarts = <Map<String, Object?>>[];
      final probedBaseUris = <Uri>[];

      final launcher = CockpitDevelopmentSessionMachineLauncher(
        machineClientStarter: ({
          required projectDir,
          required target,
          required deviceId,
          flutterExecutable,
          extraArgs = const <String>[],
        }) async {
          capturedStarts.add(<String, Object?>{
            'projectDir': projectDir,
            'target': target,
            'deviceId': deviceId,
            'flutterExecutable': flutterExecutable,
            'extraArgs': extraArgs,
          });
          final client = CockpitFlutterRunMachineClient(
            stdoutLines: stdoutController.stream,
            stderrLines: stderrController.stream,
            exitCode: exitCode.future,
            requestWriter: (_) async {},
          );
          stdoutController.add(
            '[{"event":"app.start","params":{"appId":"machine-web-app"}}]',
          );
          return client;
        },
        statusReader: (baseUri) async {
          probedBaseUris.add(baseUri);
          return _readyStatus('web');
        },
        now: () => DateTime.utc(2026, 4, 4, 17),
      );

      final result = await launcher.launch(
        const CockpitLaunchDevelopmentMachineSessionRequest(
          projectDir: '/workspace/examples/cockpit_demo',
          target: 'cockpit/main.dart',
          platform: 'web',
          deviceId: 'chrome',
          sessionPort: 59331,
          hostPort: 59331,
          launchTimeout: Duration(seconds: 10),
          flutterVersion: '3.39.0',
          flutterExecutable: '/opt/flutter/bin/flutter',
        ),
      );

      expect(capturedStarts, hasLength(1));
      expect(
        capturedStarts.single['extraArgs'],
        <String>[
          '--dart-define=FLUTTER_PILOT_REMOTE_ENABLED=true',
          '--dart-define=FLUTTER_PILOT_REMOTE_HOST=localhost',
          '--dart-define=FLUTTER_PILOT_REMOTE_PORT=59331',
          '--dart-define=FLUTTER_PILOT_FLUTTER_VERSION=3.39.0',
        ],
      );
      expect(probedBaseUris, <Uri>[Uri.parse('http://localhost:59331')]);
      expect(result.remoteSessionHandle.host, 'localhost');
      expect(result.remoteSessionHandle.baseUrl, 'http://localhost:59331');

      await stdoutController.close();
      await stderrController.close();
      exitCode.complete(0);
      await result.machineClient.dispose();
    },
  );
}

final class _RecordingPortForwarder extends CockpitAndroidPortForwarder {
  const _RecordingPortForwarder(this.hostPort);

  final int hostPort;

  @override
  Future<int> ensureForwarded({
    required String deviceId,
    required int preferredHostPort,
    required int devicePort,
  }) async {
    expect(deviceId, 'emulator-5554');
    expect(preferredHostPort, 57331);
    expect(devicePort, 47331);
    return hostPort;
  }
}

CockpitRemoteSessionStatus _readyStatus(String platform) {
  return CockpitRemoteSessionStatus(
    sessionId: 'remote-session-1',
    platform: platform,
    transportType: 'http',
    currentRouteName: '/inbox',
    capabilities: CockpitCapabilities(
      platform: platform,
      transportType: 'http',
      supportsInAppControl: true,
      supportsFlutterViewCapture: true,
      supportsNativeScreenCapture: false,
      supportsHostAutomation: false,
    ),
    recordingCapabilities: CockpitRecordingCapabilities(
      supportsNativeRecording: false,
    ),
    snapshot: CockpitSnapshot(routeName: '/inbox'),
  );
}
