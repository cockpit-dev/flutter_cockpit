import 'cockpit_mcp_feature_category.dart';
import 'cockpit_mcp_feature_descriptor.dart';

final class CockpitMcpResourceDefinition
    implements CockpitMcpFeatureDescriptor {
  const CockpitMcpResourceDefinition.fixed({
    required this.name,
    required this.uri,
    required this.description,
    this.mimeType,
    this.categories = const <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.contextResources,
    ],
    this.enabledByDefault = true,
  }) : uriTemplate = null;

  const CockpitMcpResourceDefinition.template({
    required this.name,
    required this.uriTemplate,
    required this.description,
    this.mimeType,
    this.categories = const <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.contextResources,
    ],
    this.enabledByDefault = true,
  }) : uri = null;

  @override
  final String name;
  final String? uri;
  final String? uriTemplate;
  final String description;
  final String? mimeType;
  @override
  final List<CockpitMcpFeatureCategory> categories;
  @override
  final bool enabledByDefault;

  bool get isTemplate => uriTemplate != null;
}
