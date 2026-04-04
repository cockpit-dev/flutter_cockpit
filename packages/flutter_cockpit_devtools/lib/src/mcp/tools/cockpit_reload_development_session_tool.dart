import '../../application/cockpit_reload_development_session_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../../development/cockpit_development_session_status.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitReloadDevelopmentSessionToolFunction
    = Future<CockpitReloadDevelopmentSessionResult> Function(
  CockpitReloadDevelopmentSessionRequest request,
);

final class CockpitReloadDevelopmentSessionTool extends CockpitMcpTool {
  CockpitReloadDevelopmentSessionTool({
    CockpitReloadDevelopmentSessionService? service,
    CockpitReloadDevelopmentSessionToolFunction? reload,
    CockpitSessionRegistry? sessionRegistry,
  })  : _reload = reload ??
            (service ?? CockpitReloadDevelopmentSessionService()).reload,
        _sessionRegistry = sessionRegistry;

  final CockpitReloadDevelopmentSessionToolFunction _reload;
  final CockpitSessionRegistry? _sessionRegistry;

  @override
  String get name => 'reload_development_session';

  @override
  String get description =>
      'Trigger hot reload or hot restart for a development session.';

  @override
  Map<String, Object?> get inputSchema => <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'sessionHandle': const <String, Object?>{'type': 'object'},
          'sessionHandlePath': const <String, Object?>{'type': 'string'},
          'mode': <String, Object?>{
            'type': 'string',
            'enum': CockpitDevelopmentReloadMode.values
                .map((value) => value.jsonValue)
                .toList(growable: false),
          },
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _reload(
        CockpitReloadDevelopmentSessionRequest(
          sessionHandle: cockpitReadOptionalDevelopmentSessionHandle(arguments),
          sessionHandlePath: cockpitReadOptionalString(
            arguments,
            'sessionHandlePath',
          ),
          mode: CockpitDevelopmentReloadMode.fromJson(
            cockpitReadOptionalString(arguments, 'mode') ??
                CockpitDevelopmentReloadMode.hotReload.jsonValue,
          ),
        ),
      );
      _sessionRegistry?.recordDevelopmentSession(
        handle: result.sessionHandle,
        status: result.status,
      );
      return cockpitMcpResult(
        text: 'Development session reloaded.',
        structuredContent: <String, Object?>{
          'sessionHandle': result.sessionHandle.toJson(),
          'status': result.status.toJson(),
          'sessionHandlePath': result.persistedHandlePath,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
