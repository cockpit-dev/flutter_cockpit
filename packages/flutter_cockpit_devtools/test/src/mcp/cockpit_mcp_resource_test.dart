import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_feature_category.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_resource_definition.dart';
import 'package:test/test.dart';

void main() {
  test('fixed resource definition preserves URI metadata', () {
    const definition = CockpitMcpResourceDefinition.fixed(
      name: 'workspace_goals',
      uri: 'cockpit://workspace/goals',
      description: 'Repository goals.',
      mimeType: 'text/markdown',
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.contextResources,
      ],
    );

    expect(definition.isTemplate, isFalse);
    expect(definition.uri, 'cockpit://workspace/goals');
    expect(definition.uriTemplate, isNull);
    expect(definition.mimeType, 'text/markdown');
  });

  test('template resource definition preserves URI template metadata', () {
    const definition = CockpitMcpResourceDefinition.template(
      name: 'task_summary',
      uriTemplate: 'cockpit://task/summary{?bundle_dir}',
      description: 'Task bundle summary.',
      mimeType: 'application/json',
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.contextResources,
      ],
    );

    expect(definition.isTemplate, isTrue);
    expect(definition.uri, isNull);
    expect(definition.uriTemplate, 'cockpit://task/summary{?bundle_dir}');
    expect(definition.mimeType, 'application/json');
  });
}
