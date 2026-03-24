import '../../application/cockpit_query_development_session_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitQueryDevelopmentSessionToolFunction
    = Future<CockpitQueryDevelopmentSessionResult> Function(
  CockpitQueryDevelopmentSessionRequest request,
);

final class CockpitQueryDevelopmentSessionTool extends CockpitMcpTool {
  CockpitQueryDevelopmentSessionTool({
    CockpitQueryDevelopmentSessionService? service,
    CockpitQueryDevelopmentSessionToolFunction? query,
  }) : _query =
            query ?? (service ?? CockpitQueryDevelopmentSessionService()).query;

  final CockpitQueryDevelopmentSessionToolFunction _query;

  @override
  String get name => 'query_development_session';

  @override
  String get description =>
      'Read lifecycle status and next-step guidance for a running development session.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'session_handle': <String, Object?>{'type': 'object'},
          'session_handle_path': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _query(
        CockpitQueryDevelopmentSessionRequest(
          sessionHandle: cockpitReadOptionalDevelopmentSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Development session status loaded.',
        structuredContent: <String, Object?>{
          'status': result.status.toJson(),
          'session_handle': result.sessionHandle?.toJson(),
          'recommended_next_step': result.recommendedNextStep,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
