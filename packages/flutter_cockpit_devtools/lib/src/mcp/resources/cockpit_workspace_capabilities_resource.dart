import 'dart:convert';

import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_feature_configuration.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';

final class CockpitWorkspaceCapabilitiesResource extends CockpitMcpResource {
  const CockpitWorkspaceCapabilitiesResource({
    required this.serverName,
    required this.serverVersion,
    required this.featureConfiguration,
  });

  final String serverName;
  final String serverVersion;
  final CockpitMcpFeatureConfiguration featureConfiguration;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspace_capabilities',
        uri: 'cockpit://workspace/capabilities',
        description: 'The configured MCP server capabilities and feature flags.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(CockpitMcpResourceRequest request) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final payload = <String, Object?>{
      'serverName': serverName,
      'serverVersion': serverVersion,
      'enabledNames': featureConfiguration.enabledNames.toList()..sort(),
      'disabledNames': featureConfiguration.disabledNames.toList()..sort(),
      'categories': CockpitMcpFeatureCategory.values
          .map((category) => category.serializedName)
          .toList(growable: false),
    };
    return CockpitMcpResourceResult(
      contents: <CockpitMcpResourceContents>[
        CockpitMcpTextResourceContents(
          uri: request.uri,
          text: const JsonEncoder.withIndent('  ').convert(payload),
          mimeType: definition.mimeType,
        ),
      ],
    );
  }
}
