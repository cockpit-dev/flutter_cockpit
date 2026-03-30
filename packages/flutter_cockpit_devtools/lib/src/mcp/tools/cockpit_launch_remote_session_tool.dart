import '../../application/cockpit_launch_remote_session_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_mcp_error.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitLaunchRemoteSessionFunction
    = Future<CockpitLaunchRemoteSessionResult> Function(
  CockpitLaunchRemoteSessionRequest request,
);

final class CockpitLaunchRemoteSessionTool extends CockpitMcpTool {
  CockpitLaunchRemoteSessionTool({
    CockpitLaunchRemoteSessionService? service,
    CockpitLaunchRemoteSessionFunction? launch,
    CockpitSessionRegistry? sessionRegistry,
  })  : _launch =
            launch ?? (service ?? CockpitLaunchRemoteSessionService()).launch,
        _sessionRegistry = sessionRegistry;

  final CockpitLaunchRemoteSessionFunction _launch;
  final CockpitSessionRegistry? _sessionRegistry;

  @override
  String get name => 'launch_remote_session';

  @override
  String get description =>
      'Launch a Flutter app on Android, iOS, or macOS and wait for a reachable flutter_cockpit remote session.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'required': <String>[
          'project_dir',
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
        CockpitLaunchRemoteSessionRequest(
          projectDir: cockpitReadRequiredString(arguments, 'project_dir'),
          target: cockpitReadOptionalString(arguments, 'target'),
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
      _sessionRegistry?.recordRemoteSession(
        handle: result.sessionHandle,
        status: result.health,
        recommendedNextStep: result.health.capabilities.supportsInAppControl
            ? 'ready_for_commands'
            : 'limited_capabilities',
      );

      return cockpitMcpResult(
        text: 'Remote session launched and ready.',
        structuredContent: <String, Object?>{
          'session_handle': result.sessionHandle.toJson(),
          'session_handle_path': result.persistedHandlePath,
          'health': result.health.toJson(),
        },
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
