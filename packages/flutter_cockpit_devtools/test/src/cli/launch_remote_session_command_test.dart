import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/launch_remote_session_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'launch-remote-session writes a reusable session handle json payload',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_launch_remote_session_cli',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final outputFile = File(p.join(tempDir.path, 'session_handle.json'));
      final runner = CommandRunner<int>(
        'flutter_cockpit_devtools',
        'Host-side tooling for flutter_cockpit.',
      )..addCommand(
          LaunchRemoteSessionCommand(
            service: CockpitLaunchRemoteSessionService(
              launcher: _FakeRemoteSessionLauncher(),
              statusReader: (_) async => CockpitRemoteSessionStatus(
                sessionId: 'launch-demo',
                platform: 'android',
                transportType: 'remoteHttp',
                currentRouteName: '/home',
                capabilities: CockpitCapabilities(
                  platform: 'android',
                  transportType: 'remoteHttp',
                  supportsInAppControl: true,
                  supportsFlutterViewCapture: true,
                  supportsNativeScreenCapture: true,
                  supportsHostAutomation: false,
                  supportedCommands: <CockpitCommandType>[
                    CockpitCommandType.tap,
                  ],
                  supportedLocatorStrategies: CockpitLocatorKind.values,
                ),
                recordingCapabilities: CockpitRecordingCapabilities(
                  supportsNativeRecording: true,
                  preferredAcceptanceRecordingKind:
                      CockpitRecordingKind.nativeScreen,
                ),
                snapshot: CockpitSnapshot(routeName: '/home'),
              ),
            ),
          ),
        );

      final exitCode = await runner.run(<String>[
            'launch-remote-session',
            '--project-dir',
            '/workspace/examples/cockpit_demo',
            '--target',
            'lib/main.dart',
            '--platform',
            'android',
            '--android-device-id',
            'emulator-5554',
            '--output-json',
            outputFile.path,
          ]) ??
          0;

      expect(exitCode, 0);
      final decoded =
          jsonDecode(await outputFile.readAsString()) as Map<String, Object?>;
      expect(decoded['platform'], 'android');
      expect(decoded['deviceId'], 'emulator-5554');
      expect(decoded['baseUrl'], 'http://127.0.0.1:58421');
    },
  );
}

final class _FakeRemoteSessionLauncher implements CockpitRemoteSessionLauncher {
  @override
  Future<CockpitRemoteSessionHandle> launch(
    CockpitRemoteSessionLaunchOptions options,
  ) async {
    return CockpitRemoteSessionHandle(
      platform: options.platform,
      deviceId: options.deviceId,
      projectDir: options.projectDir,
      target: options.target,
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 58421,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:58421',
      launchedAt: DateTime.utc(2026, 3, 21, 0, 0),
    );
  }
}
