import 'dart:convert';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/query_development_session_command.dart';
import 'package:test/test.dart';

void main() {
  test(
    'query-development-session prints status and next-step guidance',
    () async {
      CockpitQueryDevelopmentSessionRequest? capturedRequest;
      final output = StringBuffer();
      final runner = CommandRunner<int>('flutter_cockpit_devtools', 'test')
        ..addCommand(
          QueryDevelopmentSessionCommand(
            stdoutSink: output,
            query: (request) async {
              capturedRequest = request;
              return CockpitQueryDevelopmentSessionResult(
                status: CockpitDevelopmentSessionStatus(
                  developmentSessionId: 'dev-session-1',
                  state: CockpitDevelopmentSessionState.ready,
                  appReachable: true,
                  remoteSessionReachable: true,
                  reloadGeneration: 3,
                  lastStatusAt: DateTime.utc(2026, 3, 23),
                ),
                sessionHandle: null,
                recommendedNextStep: 'ready_for_incremental_probe',
              );
            },
          ),
        );

      final exitCode = await runner.run(<String>[
            'query-development-session',
            '--session-json',
            '/tmp/dev-session.json',
          ]) ??
          0;

      expect(exitCode, 0);
      expect(capturedRequest?.sessionHandlePath, '/tmp/dev-session.json');
      final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
      expect(decoded['recommendedNextStep'], 'ready_for_incremental_probe');
    },
  );
}
