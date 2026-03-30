import 'cockpit_mcp_feature_category.dart';
import 'cockpit_mcp_feature_descriptor.dart';

final class CockpitMcpPromptArgument {
  const CockpitMcpPromptArgument({
    required this.name,
    this.description,
    this.required = false,
  });

  final String name;
  final String? description;
  final bool required;
}

final class CockpitMcpPromptDefinition implements CockpitMcpFeatureDescriptor {
  const CockpitMcpPromptDefinition({
    required this.name,
    required this.description,
    this.arguments = const <CockpitMcpPromptArgument>[],
    this.categories = const <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.workflowPrompts,
    ],
    this.enabledByDefault = true,
  });

  @override
  final String name;
  final String description;
  final List<CockpitMcpPromptArgument> arguments;
  @override
  final List<CockpitMcpFeatureCategory> categories;
  @override
  final bool enabledByDefault;
}
