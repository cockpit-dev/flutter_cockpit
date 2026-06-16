import '../../application/cockpit_compact_json.dart';
import '../../application/cockpit_read_latest_task_summary_service.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitLatestTaskResource extends CockpitMcpResource {
  const CockpitLatestTaskResource({
    required CockpitReadLatestTaskSummaryService service,
  }) : _service = service;

  final CockpitReadLatestTaskSummaryService _service;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'latest_task',
        uri: 'cockpit://task/latest',
        description:
            'The latest task summary recorded by this MCP server process.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.closedLoop,
          CockpitMcpFeatureCategory.delivery,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
    CockpitMcpResourceRequest request,
  ) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final latest = _service.read();
    final payload =
        latest?.toJson() ??
        const <String, Object?>{
          'state': 'empty',
          'message': 'No task run has been recorded in this MCP server yet.',
        };
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: cockpitPrettyJsonText(payload),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}
