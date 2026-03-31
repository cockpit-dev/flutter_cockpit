import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/launch_app_command.dart';
import 'package:test/test.dart';

void main() {
  test('launch-app writes normalized app payload', () async {
    CockpitLaunchAppRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchAppCommand(
          stdoutSink: output,
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchAppResult(
              app: CockpitAppHandle.fromDevelopmentSession(
                CockpitDevelopmentSessionHandle(
                  developmentSessionId: 'dev-session-1',
                  platform: 'android',
                  deviceId: 'emulator-5554',
                  projectDir: '/workspace/examples/cockpit_demo',
                  target: 'lib/main.dart',
                  appId: 'dev.cockpit.demo',
                  appBaseUrl: 'http://127.0.0.1:57331',
                  supervisorBaseUrl: 'http://127.0.0.1:59331',
                  launchedAt: DateTime.utc(2026, 3, 30),
                  reloadGeneration: 0,
                ),
              ),
              appJsonPath: '/tmp/app.json',
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-app',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--target',
          'lib/main.dart',
          '--platform',
          'android',
          '--device-id',
          'emulator-5554',
          '--session-port',
          '57331',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.deviceId, 'emulator-5554');
    expect(capturedRequest?.mode.jsonValue, 'development');
    expect(capturedRequest?.launchTimeout, const Duration(seconds: 120));
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    final app = decoded['app'] as Map<String, Object?>;
    expect(app['app_id'], 'dev.cockpit.demo');
    expect(app['development_session_id'], isNotNull);
    expect(app['supervisor_base_url'], isNotNull);
    expect(app.containsKey('development_session'), isFalse);
    expect(app.containsKey('remote_session'), isFalse);
  });

  test('launch-app accepts an omitted target so the service can infer it',
      () async {
    CockpitLaunchAppRequest? capturedRequest;
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchAppCommand(
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchAppResult(
              app: CockpitAppHandle.fromDevelopmentSession(
                CockpitDevelopmentSessionHandle(
                  developmentSessionId: 'dev-session-1',
                  platform: 'macos',
                  deviceId: 'macos',
                  projectDir: '/workspace/examples/cockpit_demo',
                  target: 'cockpit/main.dart',
                  appId: 'dev.cockpit.demo',
                  appBaseUrl: 'http://127.0.0.1:57331',
                  supervisorBaseUrl: 'http://127.0.0.1:59331',
                  launchedAt: DateTime.utc(2026, 3, 30),
                  reloadGeneration: 0,
                ),
              ),
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-app',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--platform',
          'macos',
          '--session-port',
          '57331',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.target, isNull);
  });

  test('launch-app forwards explicit launch timeout seconds', () async {
    CockpitLaunchAppRequest? capturedRequest;
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchAppCommand(
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchAppResult(
              app: CockpitAppHandle.fromDevelopmentSession(
                CockpitDevelopmentSessionHandle(
                  developmentSessionId: 'dev-session-1',
                  platform: 'macos',
                  deviceId: 'macos',
                  projectDir: '/workspace/examples/cockpit_demo',
                  target: 'cockpit/main.dart',
                  appId: 'dev.cockpit.demo',
                  appBaseUrl: 'http://127.0.0.1:57331',
                  supervisorBaseUrl: 'http://127.0.0.1:59331',
                  launchedAt: DateTime.utc(2026, 3, 30),
                  reloadGeneration: 0,
                ),
              ),
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-app',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--platform',
          'macos',
          '--session-port',
          '57331',
          '--launch-timeout-seconds',
          '360',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.launchTimeout, const Duration(seconds: 360));
  });
}
