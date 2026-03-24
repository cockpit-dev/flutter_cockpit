import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:flutter_cockpit_devtools/src/mcp/tools/cockpit_query_development_session_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'query development tool forwards handle path and returns next step',
    () async {
      CockpitQueryDevelopmentSessionRequest? capturedRequest;
      final tool = CockpitQueryDevelopmentSessionTool(
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
      );

      final result = await tool.call(<String, Object?>{
        'session_handle_path': '/tmp/dev-session.json',
      });

      expect(capturedRequest?.sessionHandlePath, '/tmp/dev-session.json');
      final structured = result['structuredContent'] as Map<String, Object?>;
      expect(
        structured['recommended_next_step'],
        'ready_for_incremental_probe',
      );
    },
  );
}
