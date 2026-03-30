import '../../application/cockpit_query_remote_session_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitQueryRemoteSessionFunction
    = Future<CockpitQueryRemoteSessionResult> Function(
  CockpitQueryRemoteSessionRequest request,
);

final class CockpitQueryRemoteSessionTool extends CockpitMcpTool {
  CockpitQueryRemoteSessionTool({
    CockpitQueryRemoteSessionService? service,
    CockpitQueryRemoteSessionFunction? query,
  }) : _query = query ?? (service ?? CockpitQueryRemoteSessionService()).query;

  final CockpitQueryRemoteSessionFunction _query;

  @override
  String get name => 'query_remote_session';

  @override
  String get description =>
      'Read health and capabilities from a running flutter_cockpit remote session.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: true,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.sessionManagement,
        CockpitMcpFeatureCategory.inspection,
      ];

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
        CockpitQueryRemoteSessionRequest(
          sessionHandle: cockpitReadOptionalSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'session_handle_path',
          ),
        ),
      );

      return cockpitMcpResult(
        text: 'Remote session status loaded.',
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
