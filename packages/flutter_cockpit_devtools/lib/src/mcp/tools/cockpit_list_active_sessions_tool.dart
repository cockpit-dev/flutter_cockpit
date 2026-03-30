import '../../application/cockpit_list_active_sessions_service.dart';
import '../../application/cockpit_session_registry.dart';
import '../cockpit_mcp_tool.dart';

typedef CockpitListActiveSessionsToolFunction = CockpitActiveSessionsSnapshot
    Function();

final class CockpitListActiveSessionsTool extends CockpitMcpTool {
  CockpitListActiveSessionsTool({
    required CockpitListActiveSessionsService service,
    CockpitListActiveSessionsToolFunction? list,
  }) : _list = list ?? service.list;

  final CockpitListActiveSessionsToolFunction _list;

  @override
  String get name => 'list_active_sessions';

  @override
  String get description =>
      'List the active development and remote sessions known to this MCP server process.';

  @override
  CockpitMcpToolAnnotations get annotations => const CockpitMcpToolAnnotations(
        readOnly: true,
        destructive: false,
        idempotent: true,
        longRunning: false,
        requiresSession: false,
        producesBundleEvidence: false,
      );

  @override
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.closedLoop,
        CockpitMcpFeatureCategory.sessionManagement,
        CockpitMcpFeatureCategory.inspection,
      ];

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{},
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    try {
      return cockpitMcpResult(
        text: 'Active sessions loaded.',
        structuredContent: _list().toJson(),
      );
    } on Object catch (error) {
      cockpitRethrowAsMcpError(error);
    }
  }
}
