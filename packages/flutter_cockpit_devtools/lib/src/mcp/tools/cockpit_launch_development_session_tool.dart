import '../../application/cockpit_launch_development_session_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitLaunchDevelopmentSessionToolFunction =
    Future<CockpitLaunchDevelopmentSessionResult> Function(
      CockpitLaunchDevelopmentSessionRequest request,
    );

final class CockpitLaunchDevelopmentSessionTool extends CockpitMcpTool {
  CockpitLaunchDevelopmentSessionTool({
    CockpitLaunchDevelopmentSessionService? service,
    CockpitLaunchDevelopmentSessionToolFunction? launch,
    CockpitSessionRegistry? sessionRegistry,
  }) : _launch =
           launch ??
           (service ?? CockpitLaunchDevelopmentSessionService()).launch,
       _sessionRegistry = sessionRegistry;

  final CockpitLaunchDevelopmentSessionToolFunction _launch;
  final CockpitSessionRegistry? _sessionRegistry;

  @override
  String get name => 'launch_development_session';

  @override
  String get description =>
      'Launch a long-lived Flutter development session that supports hot reload, probes, and final validation.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'required': <String>['projectDir', 'platform', 'deviceId', 'sessionPort'],
    'properties': <String, Object?>{
      'projectDir': <String, Object?>{'type': 'string'},
      'target': <String, Object?>{'type': 'string'},
      'platform': <String, Object?>{
        'type': 'string',
        'enum': <String>['android', 'ios', 'macos', 'windows', 'linux'],
      },
      'deviceId': <String, Object?>{'type': 'string'},
      'sessionPort': <String, Object?>{'type': 'integer'},
      'launchTimeoutSeconds': <String, Object?>{'type': 'integer'},
      'persistHandlePath': <String, Object?>{'type': 'string'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final platform = cockpitReadRequiredString(arguments, 'platform');
      if (platform != 'android' &&
          platform != 'ios' &&
          platform != 'macos' &&
          platform != 'windows' &&
          platform != 'linux') {
        throw CockpitMcpError.invalidArguments(
          'platform must be android, ios, macos, windows, or linux.',
          details: <String, Object?>{'argument': 'platform'},
        );
      }
      final result = await _launch(
        CockpitLaunchDevelopmentSessionRequest(
          projectDir: cockpitReadRequiredString(arguments, 'projectDir'),
          target: cockpitReadOptionalString(arguments, 'target'),
          platform: platform,
          deviceId: cockpitReadRequiredString(arguments, 'deviceId'),
          sessionPort: cockpitReadRequiredPort(arguments, 'sessionPort'),
          launchTimeout: Duration(
            seconds:
                cockpitReadOptionalPositiveInt(
                  arguments,
                  'launchTimeoutSeconds',
                ) ??
                120,
          ),
          persistHandlePath: cockpitReadOptionalString(
            arguments,
            'persistHandlePath',
          ),
        ),
      );
      _sessionRegistry?.recordDevelopmentSession(
        handle: result.sessionHandle,
        status: result.status,
        supervisorLogPath: result.supervisorLogPath,
      );
      return cockpitMcpResult(
        text: 'Development session launched and ready.',
        structuredContent: <String, Object?>{
          'sessionHandle': result.sessionHandle.toJson(),
          'status': result.status.toJson(),
          'sessionHandlePath': result.persistedHandlePath,
          'supervisorLogPath': result.supervisorLogPath,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
