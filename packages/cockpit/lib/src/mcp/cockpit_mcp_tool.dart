export 'core/cockpit_mcp_feature_category.dart';
export 'core/cockpit_mcp_feature_configuration.dart';
export 'core/cockpit_mcp_tool_annotations.dart';
export 'core/cockpit_mcp_tool_definition.dart';

import 'core/cockpit_mcp_feature_category.dart';
import 'core/cockpit_mcp_tool_annotations.dart';
import 'core/cockpit_mcp_tool_definition.dart';

abstract base class CockpitMcpTool {
  String get name;
  String get description;
  Map<String, Object?> get inputSchema;
  CockpitMcpToolAnnotations get annotations =>
      CockpitMcpToolAnnotations.defaults;
  List<CockpitMcpFeatureCategory> get categories =>
      const <CockpitMcpFeatureCategory>[CockpitMcpFeatureCategory.all];
  bool get enabledByDefault => true;

  CockpitMcpToolDefinition get definition => CockpitMcpToolDefinition(
    name: name,
    description: description,
    inputSchema: inputSchema,
    annotations: annotations,
    categories: categories,
    enabledByDefault: enabledByDefault,
  );

  Future<Map<String, Object?>> call(Map<String, Object?> arguments);

  Map<String, Object?> toDescriptor() => definition.toDescriptor();
}
