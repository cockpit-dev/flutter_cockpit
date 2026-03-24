import '../../application/cockpit_launch_development_session_service.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitLaunchDevelopmentSessionToolFunction
    = Future<CockpitLaunchDevelopmentSessionResult> Function(
  CockpitLaunchDevelopmentSessionRequest request,
);

final class CockpitLaunchDevelopmentSessionTool extends CockpitMcpTool {
  CockpitLaunchDevelopmentSessionTool({
    CockpitLaunchDevelopmentSessionService? service,
    CockpitLaunchDevelopmentSessionToolFunction? launch,
  }) : _launch = launch ??
            (service ?? CockpitLaunchDevelopmentSessionService()).launch;

  final CockpitLaunchDevelopmentSessionToolFunction _launch;

  @override
  String get name => 'launch_development_session';

  @override
  String get description =>
      'Launch a long-lived Flutter development session that supports hot reload, probes, and final validation.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>[
          'project_dir',
          'target',
          'platform',
          'device_id',
          'session_port',
        ],
        'properties': <String, Object?>{
          'project_dir': <String, Object?>{'type': 'string'},
          'target': <String, Object?>{'type': 'string'},
          'platform': <String, Object?>{
            'type': 'string',
            'enum': <String>['android', 'ios', 'macos', 'windows', 'linux'],
          },
          'device_id': <String, Object?>{'type': 'string'},
          'session_port': <String, Object?>{'type': 'integer'},
          'launch_timeout_seconds': <String, Object?>{'type': 'integer'},
          'persist_handle_path': <String, Object?>{'type': 'string'},
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
          projectDir: cockpitReadRequiredString(arguments, 'project_dir'),
          target: cockpitReadRequiredString(arguments, 'target'),
          platform: platform,
          deviceId: cockpitReadRequiredString(arguments, 'device_id'),
          sessionPort: cockpitReadRequiredInt(arguments, 'session_port'),
          launchTimeout: Duration(
            seconds:
                cockpitReadOptionalInt(arguments, 'launch_timeout_seconds') ??
                    120,
          ),
          persistHandlePath: cockpitReadOptionalString(
            arguments,
            'persist_handle_path',
          ),
        ),
      );
      return cockpitMcpResult(
        text: 'Development session launched and ready.',
        structuredContent: <String, Object?>{
          'session_handle': result.sessionHandle.toJson(),
          'status': result.status.toJson(),
          'session_handle_path': result.persistedHandlePath,
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
