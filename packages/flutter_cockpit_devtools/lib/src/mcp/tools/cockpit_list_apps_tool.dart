import '../../application/cockpit_list_apps_service.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitListAppsToolFunction = CockpitListAppsResult Function();

final class CockpitListAppsTool extends CockpitMcpTool {
  CockpitListAppsTool({
    required CockpitListAppsService service,
    CockpitListAppsToolFunction? list,
  }) : _list = list ?? service.list;

  final CockpitListAppsToolFunction _list;

  @override
  String get name => 'list_apps';

  @override
  String get description =>
      'List the active apps known to this MCP server process.';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{},
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      return cockpitMcpResult(
        text: 'Active apps loaded.',
        structuredContent: _list().toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
