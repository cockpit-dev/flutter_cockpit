import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_wait_remote_ui_idle_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/wait_remote_ui_idle_command.dart';
import 'package:test/test.dart';

void main() {
  test('wait-remote-ui-idle parses timing arguments', () async {
    CockpitWaitRemoteUiIdleRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        WaitRemoteUiIdleCommand(
          stdoutSink: stdoutBuffer,
          wait: (request) async {
            capturedRequest = request;
            return const CockpitWaitRemoteUiIdleResult(
              idle: true,
              durationMs: 10,
              quietWindowMs: 150,
              timeoutMs: 2000,
              includeNetworkIdle: false,
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'wait-remote-ui-idle',
          '--base-url',
          'http://127.0.0.1:47331',
          '--quiet-window-ms',
          '150',
          '--timeout-ms',
          '2000',
          '--no-include-network-idle',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.quietWindow.inMilliseconds, 150);
    expect(capturedRequest?.timeout.inMilliseconds, 2000);
    expect(capturedRequest?.includeNetworkIdle, isFalse);
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['idle'], isTrue);
  });
}
