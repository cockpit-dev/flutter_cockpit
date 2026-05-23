import '../../application/cockpit_hot_reload_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitHotReloadToolFunction =
    Future<CockpitHotReloadResult> Function(CockpitHotReloadRequest request);

final class CockpitHotReloadTool extends CockpitMcpTool {
  CockpitHotReloadTool({
    CockpitHotReloadService? service,
    CockpitHotReloadToolFunction? reload,
  }) : _reload = reload ?? (service ?? CockpitHotReloadService()).reload;

  final CockpitHotReloadToolFunction _reload;

  @override
  String get name => 'hot_reload';

  @override
  String get description => 'Trigger hot reload for a tracked development app.';

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
      final result = await _reload(
        CockpitHotReloadRequest(
          appId: cockpitReadOptionalString(arguments, 'appId'),
          appHandlePath: cockpitReadOptionalString(arguments, 'appJson'),
        ),
      );
      return cockpitMcpResult(
        text: 'Hot reload completed.',
        structuredContent: result.toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
