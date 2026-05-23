import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/application/cockpit_read_errors_service.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/read_errors_command.dart';
import 'package:test/test.dart';

void main() {
  test('read-errors accepts app references and writes structured JSON',
      () async {
    CockpitReadErrorsRequest? capturedRequest;
    final stdoutBuffer = StringBuffer();
    final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
      ..addCommand(
        ReadErrorsCommand(
          stdoutSink: stdoutBuffer,
          read: (request) async {
            capturedRequest = request;
            return const CockpitReadErrorsResult(
              appId: 'dev.example.app',
              routeName: '/inbox',
              source: 'app_snapshot',
              errors: <CockpitErrorEntry>[
                CockpitErrorEntry(
                  source: 'app_snapshot',
                  message: 'boom',
                  kind: 'flutterError',
                ),
              ],
            );
          },
        ),
      );

    final exitCode = await runner.run(<String>[
          'read-errors',
          '--app-json',
          '/tmp/app.json',
          '--max-errors',
          '12',
          '--no-include-latest-task',
          '--no-include-sessions',
          '--stdout-format',
          'json',
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedRequest?.appHandlePath, '/tmp/app.json');
    expect(capturedRequest?.maxErrors, 12);
    expect(capturedRequest?.includeLatestTask, isFalse);
    expect(capturedRequest?.includeSessions, isFalse);
    final decoded = jsonDecode(stdoutBuffer.toString()) as Map<String, Object?>;
    expect(decoded['appId'], 'dev.example.app');
    expect(decoded['source'], 'app_snapshot');
    expect(decoded['hasErrors'], isTrue);
  });
}
