import '../../application/cockpit_stop_app_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitStopAppToolFunction = Future<CockpitStopAppResult> Function(
  CockpitStopAppRequest request,
);

final class CockpitStopAppTool extends CockpitMcpTool {
  CockpitStopAppTool({
    CockpitStopAppService? service,
    CockpitStopAppToolFunction? stop,
  }) : _stop = stop ?? (service ?? CockpitStopAppService()).stop;

  final CockpitStopAppToolFunction _stop;

  @override
  String get name => 'stop_app';

  @override
  String get description => 'Stop a tracked development or automation app.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'app_id': <String, Object?>{'type': 'string'},
          'app_json': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _stop(
        CockpitStopAppRequest(
          appId: cockpitReadOptionalString(arguments, 'app_id'),
          appHandlePath: cockpitReadOptionalString(arguments, 'app_json'),
        ),
      );
      return cockpitMcpResult(
        text: 'App stopped.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
