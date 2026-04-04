import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/launch_development_session_command.dart';
import 'package:test/test.dart';

void main() {
  test('launch-development-session prints handle and status payload', () async {
    CockpitLaunchDevelopmentSessionRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchDevelopmentSessionCommand(
          stdoutSink: output,
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchDevelopmentSessionResult(
              sessionHandle: _handle(reloadGeneration: 0),
              status: _status(CockpitDevelopmentSessionState.ready),
              persistedHandlePath: '/tmp/dev-session.json',
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-development-session',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--target',
          'lib/main.dart',
          '--platform',
          'android',
          '--android-device-id',
          'emulator-5554',
          '--output-json',
          '/tmp/dev-session.json',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.projectDir, '/workspace/examples/cockpit_demo');
    expect(capturedRequest?.deviceId, 'emulator-5554');
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect((decoded['status'] as Map<String, Object?>)['state'], 'ready');
    expect(
      (decoded['sessionHandle']
          as Map<String, Object?>)['developmentSessionId'],
      'dev-session-1',
    );
  });

  test('launch-development-session accepts macos without a mobile device id',
      () async {
    CockpitLaunchDevelopmentSessionRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchDevelopmentSessionCommand(
          stdoutSink: output,
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchDevelopmentSessionResult(
              sessionHandle: _macosHandle(reloadGeneration: 0),
              status: _macosStatus(CockpitDevelopmentSessionState.ready),
              persistedHandlePath: '/tmp/dev-session.json',
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-development-session',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--target',
          'cockpit/main.dart',
          '--platform',
          'macos',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.platform, 'macos');
    expect(capturedRequest?.deviceId, 'macos');
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(
      (decoded['sessionHandle'] as Map<String, Object?>)['platform'],
      'macos',
    );
  });

  test('launch-development-session accepts windows without a mobile device id',
      () async {
    CockpitLaunchDevelopmentSessionRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchDevelopmentSessionCommand(
          stdoutSink: output,
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchDevelopmentSessionResult(
              sessionHandle: _desktopHandle(
                platform: 'windows',
                deviceId: 'windows',
              ),
              status: _desktopStatus(
                sessionId: 'dev-session-windows',
                state: CockpitDevelopmentSessionState.ready,
              ),
              persistedHandlePath: '/tmp/dev-session.json',
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-development-session',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--target',
          'cockpit/main.dart',
          '--platform',
          'windows',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.platform, 'windows');
    expect(capturedRequest?.deviceId, 'windows');
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(
      (decoded['sessionHandle'] as Map<String, Object?>)['platform'],
      'windows',
    );
  });

  test('launch-development-session accepts linux without a mobile device id',
      () async {
    CockpitLaunchDevelopmentSessionRequest? capturedRequest;
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchDevelopmentSessionCommand(
          stdoutSink: output,
          launch: (request) async {
            capturedRequest = request;
            return CockpitLaunchDevelopmentSessionResult(
              sessionHandle: _desktopHandle(
                platform: 'linux',
                deviceId: 'linux',
              ),
              status: _desktopStatus(
                sessionId: 'dev-session-linux',
                state: CockpitDevelopmentSessionState.ready,
              ),
              persistedHandlePath: '/tmp/dev-session.json',
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-development-session',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--target',
          'cockpit/main.dart',
          '--platform',
          'linux',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.platform, 'linux');
    expect(capturedRequest?.deviceId, 'linux');
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(
      (decoded['sessionHandle'] as Map<String, Object?>)['platform'],
      'linux',
    );
  });

  test('launch-development-session omits null fields in the payload', () async {
    final output = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        LaunchDevelopmentSessionCommand(
          stdoutSink: output,
          launch: (_) async => CockpitLaunchDevelopmentSessionResult(
            sessionHandle: _handle(reloadGeneration: 0),
            status: _status(CockpitDevelopmentSessionState.ready),
          ),
        ),
      );

    final exitCode = await runner.run(<String>[
          'launch-development-session',
          '--project-dir',
          '/workspace/examples/cockpit_demo',
          '--platform',
          'android',
          '--android-device-id',
          'emulator-5554',
        ]) ??
        0;

    expect(exitCode, 0);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded.containsKey('persisted_handle_path'), isFalse);
  });
}

CockpitDevelopmentSessionHandle _handle({required int reloadGeneration}) {
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
    reloadGeneration: reloadGeneration,
  );
}

CockpitDevelopmentSessionStatus _status(CockpitDevelopmentSessionState state) {
  return CockpitDevelopmentSessionStatus(
    developmentSessionId: 'dev-session-1',
    state: state,
    appReachable: state == CockpitDevelopmentSessionState.ready,
    remoteSessionReachable: state == CockpitDevelopmentSessionState.ready,
    reloadGeneration: 0,
    lastStatusAt: DateTime.utc(2026, 3, 23),
  );
}

CockpitDevelopmentSessionHandle _macosHandle({required int reloadGeneration}) {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-macos',
    platform: 'macos',
    deviceId: 'macos',
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:57331',
    supervisorBaseUrl: 'http://127.0.0.1:59331',
    remoteSessionHandle: CockpitRemoteSessionHandle(
      platform: 'macos',
      deviceId: 'macos',
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 57331,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:57331',
      launchedAt: DateTime.utc(2026, 3, 23),
    ),
    launchedAt: DateTime.utc(2026, 3, 23),
    reloadGeneration: reloadGeneration,
  );
}

CockpitDevelopmentSessionStatus _macosStatus(
  CockpitDevelopmentSessionState state,
) {
  return CockpitDevelopmentSessionStatus(
    developmentSessionId: 'dev-session-macos',
    state: state,
    appReachable: state == CockpitDevelopmentSessionState.ready,
    remoteSessionReachable: state == CockpitDevelopmentSessionState.ready,
    reloadGeneration: 0,
    lastStatusAt: DateTime.utc(2026, 3, 23),
  );
}

CockpitDevelopmentSessionHandle _desktopHandle({
  required String platform,
  required String deviceId,
}) {
  return CockpitDevelopmentSessionHandle(
    developmentSessionId: 'dev-session-$platform',
    platform: platform,
    deviceId: deviceId,
    projectDir: '/workspace/examples/cockpit_demo',
    target: 'cockpit/main.dart',
    appId: 'dev.cockpit.cockpit_demo',
    appBaseUrl: 'http://127.0.0.1:57331',
    supervisorBaseUrl: 'http://127.0.0.1:59331',
    remoteSessionHandle: CockpitRemoteSessionHandle(
      platform: platform,
      deviceId: deviceId,
      projectDir: '/workspace/examples/cockpit_demo',
      target: 'cockpit/main.dart',
      appId: 'dev.cockpit.cockpit_demo',
      host: '127.0.0.1',
      hostPort: 57331,
      devicePort: 47331,
      baseUrl: 'http://127.0.0.1:57331',
      launchedAt: DateTime.utc(2026, 3, 23),
    ),
    launchedAt: DateTime.utc(2026, 3, 23),
    reloadGeneration: 0,
  );
}

CockpitDevelopmentSessionStatus _desktopStatus({
  required String sessionId,
  required CockpitDevelopmentSessionState state,
}) {
  return CockpitDevelopmentSessionStatus(
    developmentSessionId: sessionId,
    state: state,
    appReachable: state == CockpitDevelopmentSessionState.ready,
    remoteSessionReachable: state == CockpitDevelopmentSessionState.ready,
    reloadGeneration: 0,
    lastStatusAt: DateTime.utc(2026, 3, 23),
  );
}
