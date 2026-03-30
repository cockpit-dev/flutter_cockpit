import 'dart:convert';

import '../cockpit_mcp_tool.dart';
import '../core/cockpit_mcp_prompt.dart';
import '../core/cockpit_mcp_resource.dart';
import '../core/cockpit_mcp_resource_definition.dart';
import '../core/cockpit_mcp_roots_tracker.dart';

final class CockpitWorkspaceCapabilitiesResource extends CockpitMcpResource {
  CockpitWorkspaceCapabilitiesResource({
    required this.serverName,
    required this.serverVersion,
    required this.featureConfiguration,
    required this.rootsTracker,
    required List<CockpitMcpTool> tools,
    required List<CockpitMcpResource> resources,
    required List<CockpitMcpPrompt> prompts,
  })  : _tools = List<CockpitMcpTool>.unmodifiable(tools),
        _resources = List<CockpitMcpResource>.unmodifiable(resources),
        _prompts = List<CockpitMcpPrompt>.unmodifiable(prompts);

  final String serverName;
  final String serverVersion;
  final CockpitMcpFeatureConfiguration featureConfiguration;
  final CockpitMcpRootsTracker rootsTracker;
  final List<CockpitMcpTool> _tools;
  final List<CockpitMcpResource> _resources;
  final List<CockpitMcpPrompt> _prompts;

  @override
  CockpitMcpResourceDefinition get definition =>
      const CockpitMcpResourceDefinition.fixed(
        name: 'workspace_capabilities',
        uri: 'cockpit://workspace/capabilities',
        description:
            'The configured MCP server capabilities and feature flags.',
        mimeType: 'application/json',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.contextResources,
        ],
      );

  @override
  Future<CockpitMcpResourceResult?> read(
      CockpitMcpResourceRequest request) async {
    if (request.uri != definition.uri) {
      return null;
    }
    final payload = <String, Object?>{
      'server_name': serverName,
      'server_version': serverVersion,
      'enabled_names': featureConfiguration.enabledNames.toList()..sort(),
      'disabled_names': featureConfiguration.disabledNames.toList()..sort(),
      'roots': rootsTracker.toJson(),
      'categories': CockpitMcpFeatureCategory.values
          .map((category) => category.serializedName)
          .toList(growable: false),
      'tools': _tools
          .where((tool) => featureConfiguration.isEnabled(tool.definition))
          .map((tool) => tool.name)
          .toList(growable: false),
      'resources': _resources
          .where(
              (resource) => featureConfiguration.isEnabled(resource.definition))
          .map((resource) => resource.definition.name)
          .toList(growable: false),
      'prompts': _prompts
          .where((prompt) => featureConfiguration.isEnabled(prompt.definition))
          .map((prompt) => prompt.definition.name)
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
