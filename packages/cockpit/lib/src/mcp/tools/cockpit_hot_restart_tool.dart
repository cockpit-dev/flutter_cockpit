import '../../application/cockpit_hot_restart_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitHotRestartToolFunction =
    Future<CockpitHotRestartResult> Function(CockpitHotRestartRequest request);

final class CockpitHotRestartTool extends CockpitMcpTool {
  CockpitHotRestartTool({
    CockpitHotRestartService? service,
    CockpitHotRestartToolFunction? restart,
  }) : _restart = restart ?? (service ?? CockpitHotRestartService()).restart;

  final CockpitHotRestartToolFunction _restart;

  @override
  String get name => 'hot_restart';

  @override
  String get description =>
      'Trigger hot restart for a tracked development app.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'appId': <String, Object?>{'type': 'string'},
      'appJson': <String, Object?>{'type': 'string'},
    },
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      final result = await _restart(
        CockpitHotRestartRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
        ),
      );
      return cockpitMcpResult(
        text: 'Hot restart completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
