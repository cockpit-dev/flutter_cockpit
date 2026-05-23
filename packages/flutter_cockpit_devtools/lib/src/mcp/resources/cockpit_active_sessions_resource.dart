import 'dart:convert';

import '../../application/cockpit_list_active_sessions_service.dart';
import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitActiveSessionsResource extends CockpitMcpResource {
  const CockpitActiveSessionsResource({
    required CockpitListActiveSessionsService service,
  }) : _service = service;

  final CockpitListActiveSessionsService _service;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'active_sessions',
        uri: 'cockpit://session/active',
        description:
            'Known active sessions tracked by this MCP server process.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.closedLoop,
          CockpitMcpFeatureCategory.sessionManagement,
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
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: const JsonEncoder.withIndent(
            '  ',
          ).convert(_service.list().toJson()),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}
