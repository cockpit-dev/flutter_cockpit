import 'package:cockpit/src/mcp/core/cockpit_mcp_feature_category.dart';
import 'package:cockpit/src/mcp/core/cockpit_mcp_resource_definition.dart';
import 'package:test/test.dart';

void main() {
  test('fixed resource definition preserves URI metadata', () {
    const definition = CockpitMcpResourceDefinition.fixed(
      name: 'workspace_skill_contract',
      uri: 'cockpit://workspace/skill-contract',
      description: 'Skill contract.',
      mimeType: 'text/markdown',
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.contextResources,
      ],
    );

    expect(definition.isTemplate, isFalse);
    expect(definition.uri, 'cockpit://workspace/skill-contract');
    expect(definition.uriTemplate, isNull);
    expect(definition.mimeType, 'text/markdown');
  });

  test('template resource definition preserves URI template metadata', () {
    const definition = CockpitMcpResourceDefinition.template(
      name: 'task_summary',
      uriTemplate: 'cockpit://task/summary{?bundleDir}',
      description: 'Task bundle summary.',
      mimeType: 'application/json',
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.contextResources,
      ],
    );

    expect(definition.isTemplate, isTrue);
    expect(definition.uri, isNull);
    expect(definition.uriTemplate, 'cockpit://task/summary{?bundleDir}');
    expect(definition.mimeType, 'application/json');
  });
}
