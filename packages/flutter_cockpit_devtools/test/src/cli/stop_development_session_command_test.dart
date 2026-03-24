import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/stop_development_session_command.dart';
import 'package:test/test.dart';

void main() {
  test('stop-development-session prints stopped status', () async {
    CockpitStopDevelopmentSessionRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        StopDevelopmentSessionCommand(
          stdoutSink: output,
          stop: (request) async {
            capturedRequest = request;
            return CockpitStopDevelopmentSessionResult(
              sessionHandle: _handle(),
              status: CockpitDevelopmentSessionStatus(
                developmentSessionId: 'dev-session-1',
                state: CockpitDevelopmentSessionState.stopped,
                appReachable: false,
                remoteSessionReachable: false,
                reloadGeneration: 4,
                lastStatusAt: DateTime.utc(2026, 3, 23),
              ),
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'stop-development-session',
          '--session-json',
          '/tmp/dev-session.json',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.sessionHandlePath, '/tmp/dev-session.json');
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect((decoded['status'] as Map<String, Object?>)['state'], 'stopped');
  });
}

CockpitDevelopmentSessionHandle _handle() {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-1',
    platform: 'android',
    deviceId: 'emulator-5554',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'lib/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:57331',
    supervisorBaseUrl: 'http://127.0.0.1:59331',
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
      launchedAt: DateTime.utc(2026, 3, 23),
    ),
    launchedAt: DateTime.utc(2026, 3, 23),
    reloadGeneration: 4,
  );
}
