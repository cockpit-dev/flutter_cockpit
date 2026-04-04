import '../../application/cockpit_app_handle.dart';
import '../../application/cockpit_launch_app_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitLaunchAppToolFunction = Future<CockpitLaunchAppResult> Function(
  CockpitLaunchAppRequest request,
);

final class CockpitLaunchAppTool extends CockpitMcpTool {
  CockpitLaunchAppTool({
    CockpitLaunchAppService? service,
    CockpitLaunchAppToolFunction? launch,
  }) : _launch = launch ?? (service ?? CockpitLaunchAppService()).launch;

  final CockpitLaunchAppToolFunction _launch;

  @override
  String get name => 'launch_app';

  @override
  String get description =>
      'Launch a Flutter app for development or automation and return a normalized app handle.';

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
          'projectDir': <String, Object?>{'type': 'string'},
          'target': <String, Object?>{'type': 'string'},
          'platform': <String, Object?>{'type': 'string'},
          'deviceId': <String, Object?>{'type': 'string'},
          'sessionPort': <String, Object?>{'type': 'integer'},
          'mode': <String, Object?>{
            'type': 'string',
            'enum': <String>['development', 'automation'],
          },
          'launchTimeoutSeconds': <String, Object?>{'type': 'integer'},
          'appJson': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _launch(
        CockpitLaunchAppRequest(
          projectDir: cockpitReadRequiredString(arguments, 'project_dir'),
          target: cockpitReadOptionalString(arguments, 'target'),
          platform: cockpitReadRequiredString(arguments, 'platform'),
          deviceId: cockpitReadRequiredString(arguments, 'device_id'),
          sessionPort: cockpitReadRequiredInt(arguments, 'session_port'),
          mode: CockpitAppMode.fromJson(
            cockpitReadOptionalString(arguments, 'mode') ?? 'development',
          ),
          launchTimeout: Duration(
            seconds:
                cockpitReadOptionalInt(arguments, 'launch_timeout_seconds') ??
                    120,
          ),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
        ),
      );
      return cockpitMcpResult(
        text: 'App launched and ready.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
