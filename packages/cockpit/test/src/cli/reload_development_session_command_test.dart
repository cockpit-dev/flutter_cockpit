import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:cockpit/cockpit.dart';
import 'package:cockpit/src/cli/commands/reload_development_session_command.dart';
import 'package:test/test.dart';

void main() {
  test('reload-development-session supports hot_restart', () async {
    CockpitReloadDevelopmentSessionRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('cockpit', 'test')
      ..addCommand(
        ReloadDevelopmentSessionCommand(
          stdoutSink: output,
          reload: (request) async {
            capturedRequest = request;
            return CockpitReloadDevelopmentSessionResult(
              sessionHandle: _handle(4),
              status: CockpitDevelopmentSessionStatus(
                developmentSessionId: 'dev-session-1',
                state: CockpitDevelopmentSessionState.ready,
                appReachable: true,
                remoteSessionReachable: true,
                reloadGeneration: 4,
                lastReloadMode: CockpitDevelopmentReloadMode.hotRestart,
                lastReloadSucceeded: true,
                lastStatusAt: DateTime.utc(2026, 3, 23),
              ),
              persistedHandlePath: '/tmp/dev-session.json',
            );
          },
        ),
      );

    final exitCode =
        await runner.run(<String>[
          'reload-development-session',
          '--stdout-format',
          'json',
          '--session-json',
          '/tmp/dev-session.json',
          '--mode',
          'hot_restart',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.mode, CockpitDevelopmentReloadMode.hotRestart);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(
      (decoded['status'] as Map<String, Object?>)['lastReloadMode'],
      'hot_restart',
    );
  });
}

CockpitDevelopmentSessionHandle _handle(int reloadGeneration) {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-1',
    platform: 'ios',
    deviceId: 'simulator',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'lib/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:58421',
    supervisorBaseUrl: 'http://127.0.0.1:59421',
    remoteSessionHandle: CockpitRemoteSessionHandle(
      platform: 'ios',
      deviceId: 'simulator',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'lib/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 58421,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:58421',
      launchedAt: DateTime.utc(2026, 3, 23),
    ),
    launchedAt: DateTime.utc(2026, 3, 23),
    reloadGeneration: reloadGeneration,
  );
}
