import 'package:cockpit/src/mcp/core/cockpit_mcp_feature_category.dart';
import 'package:cockpit/src/mcp/core/cockpit_mcp_prompt_definition.dart';
import 'package:test/test.dart';

void main() {
  test('prompt definition preserves arguments and metadata', () {
    const definition = CockpitMcpPromptDefinition(
      name: 'run_closed_loop_task',
      description: 'Guide a full closed-loop task execution.',
      arguments: <CockpitMcpPromptArgument>[
        CockpitMcpPromptArgument(
          name: 'taskGoal',
          description: 'The requested task.',
          required: true,
        ),
        CockpitMcpPromptArgument(
          name: 'platform',
          description: 'The target platform.',
        ),
      ],
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.closedLoop,
        CockpitMcpFeatureCategory.workflowPrompts,
      ],
    );

    expect(definition.name, 'run_closed_loop_task');
    expect(definition.enabledByDefault, isTrue);
    expect(definition.categories, <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.closedLoop,
      CockpitMcpFeatureCategory.workflowPrompts,
    ]);
    expect(definition.arguments, hasLength(2));
    expect(definition.arguments.first.name, 'taskGoal');
    expect(definition.arguments.first.required, isTrue);
  });
}
