import 'cockpit_mcp_feature_category.dart';
import 'cockpit_mcp_feature_descriptor.dart';
import 'cockpit_mcp_tool_annotations.dart';

final class CockpitMcpToolDefinition implements CockpitMcpFeatureDescriptor {
  const CockpitMcpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.annotations,
    this.categories = const <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.all,
    ],
    this.enabledByDefault = true,
  });

  @override
  final String name;
  final String description;
  final Map<String, Object?> inputSchema;
  final CockpitMcpToolAnnotations annotations;
  @override
  final List<CockpitMcpFeatureCategory> categories;
  @override
  final bool enabledByDefault;

  Map<String, Object?> toDescriptor() => <String, Object?>{
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}
