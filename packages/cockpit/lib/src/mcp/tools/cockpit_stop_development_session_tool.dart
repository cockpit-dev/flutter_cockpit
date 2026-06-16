import '../../application/cockpit_stop_development_session_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitStopDevelopmentSessionToolFunction =
    Future<CockpitStopDevelopmentSessionResult> Function(
      CockpitStopDevelopmentSessionRequest request,
    );

final class CockpitStopDevelopmentSessionTool extends CockpitMcpTool {
  CockpitStopDevelopmentSessionTool({
    CockpitStopDevelopmentSessionService? service,
    CockpitStopDevelopmentSessionToolFunction? stop,
    CockpitSessionRegistry? sessionRegistry,
  }) : _stop = stop ?? (service ?? CockpitStopDevelopmentSessionService()).stop,
       _sessionRegistry = sessionRegistry;

  final CockpitStopDevelopmentSessionToolFunction _stop;
  final CockpitSessionRegistry? _sessionRegistry;

  @override
  String get name => 'stop_development_session';

  @override
  String get description => 'Stop a running development session supervisor.';

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
      final result = await _stop(
        CockpitStopDevelopmentSessionRequest(
          sessionHandle: cockpitReadOptionalDevelopmentSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'sessionHandlePath',
          ),
        ),
      );
      _sessionRegistry?.removeDevelopmentSession(
        result.sessionHandle.developmentSessionId,
      );
      return cockpitMcpResult(
        text: 'Development session stopped.',
        structuredContent: <String, Object?>{
          'sessionHandle': result.sessionHandle.toJson(),
          'status': result.status.toJson(),
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
