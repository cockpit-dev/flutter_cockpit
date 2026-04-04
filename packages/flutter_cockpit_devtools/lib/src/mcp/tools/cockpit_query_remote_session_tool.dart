import '../../application/cockpit_query_remote_session_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitQueryRemoteSessionFunction
    = Future<CockpitQueryRemoteSessionResult> Function(
  CockpitQueryRemoteSessionRequest request,
);

final class CockpitQueryRemoteSessionTool extends CockpitMcpTool {
  CockpitQueryRemoteSessionTool({
    CockpitQueryRemoteSessionService? service,
    CockpitQueryRemoteSessionFunction? query,
    CockpitSessionRegistry? sessionRegistry,
  })  : _query = query ?? (service ?? CockpitQueryRemoteSessionService()).query,
        _sessionRegistry = sessionRegistry;

  final CockpitQueryRemoteSessionFunction _query;
  final CockpitSessionRegistry? _sessionRegistry;

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
          'sessionHandle': <String, Object?>{'type': 'object'},
          'sessionHandlePath': <String, Object?>{'type': 'string'},
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
            'sessionHandlePath',
          ),
        ),
      );
      final handle = result.sessionHandle;
      if (handle != null) {
        _sessionRegistry?.recordRemoteSession(
          handle: handle,
          status: result.status,
          recommendedNextStep: result.recommendedNextStep,
        );
      }

      return cockpitMcpResult(
        text: 'Remote session status loaded.',
        structuredContent: <String, Object?>{
          'status': result.status.toJson(),
          'sessionHandle': result.sessionHandle?.toJson(),
          'recommendedNextStep': result.recommendedNextStep,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
