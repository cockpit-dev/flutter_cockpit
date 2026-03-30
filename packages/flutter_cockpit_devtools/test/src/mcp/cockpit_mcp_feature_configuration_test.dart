import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_feature_category.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_feature_configuration.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_prompt_definition.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_resource_definition.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_tool_annotations.dart';
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_tool_definition.dart';
import 'package:test/test.dart';

void main() {
  group('CockpitMcpFeatureConfiguration', () {
    const executionDefinition = CockpitMcpToolDefinition(
      name: 'run_task',
      description: 'Executes a closed-loop workflow.',
      inputSchema: <String, Object?>{'type': 'object'},
      annotations: CockpitMcpToolAnnotations(
        readOnly: false,
        destructive: false,
        idempotent: false,
        longRunning: true,
        requiresSession: false,
        producesBundleEvidence: true,
      ),
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.execution,
        CockpitMcpFeatureCategory.delivery,
      ],
      enabledByDefault: true,
    );

    const goalsResource = CockpitMcpResourceDefinition.fixed(
      name: 'workspace_goals',
      uri: 'cockpit://workspace/goals',
      description: 'Repository goals.',
      mimeType: 'text/markdown',
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.workspace,
        CockpitMcpFeatureCategory.contextResources,
      ],
    );

    const closedLoopPrompt = CockpitMcpPromptDefinition(
      name: 'run_closed_loop_task',
      description: 'Guides the AI through a full flutter_cockpit workflow.',
      arguments: <CockpitMcpPromptArgument>[
        CockpitMcpPromptArgument(
          name: 'task_goal',
          description: 'The requested task.',
          required: true,
        ),
      ],
      categories: <CockpitMcpFeatureCategory>[
        CockpitMcpFeatureCategory.closedLoop,
        CockpitMcpFeatureCategory.workflowPrompts,
      ],
    );

    test('returns the tool default when no overrides exist', () {
      const configuration = CockpitMcpFeatureConfiguration();

      expect(configuration.isEnabled(executionDefinition), isTrue);
    });

    test('returns the resource default when no overrides exist', () {
      const configuration = CockpitMcpFeatureConfiguration();

      expect(configuration.isEnabled(goalsResource), isTrue);
    });

    test('returns the prompt default when no overrides exist', () {
      const configuration = CockpitMcpFeatureConfiguration();

      expect(configuration.isEnabled(closedLoopPrompt), isTrue);
    });

    test('disabling a category disables matching tools', () {
      const configuration = CockpitMcpFeatureConfiguration(
        disabledNames: <String>{'execution'},
      );

      expect(configuration.isEnabled(executionDefinition), isFalse);
    });

    test('disabling a tool by name wins over enabled categories', () {
      const configuration = CockpitMcpFeatureConfiguration(
        enabledNames: <String>{'delivery'},
        disabledNames: <String>{'run_task'},
      );

      expect(configuration.isEnabled(executionDefinition), isFalse);
    });

    test('disabling a category disables matching resources', () {
      const configuration = CockpitMcpFeatureConfiguration(
        disabledNames: <String>{'context_resources'},
      );

      expect(configuration.isEnabled(goalsResource), isFalse);
    });

    test('disabling a category disables matching prompts', () {
      const configuration = CockpitMcpFeatureConfiguration(
        disabledNames: <String>{'workflow_prompts'},
      );

      expect(configuration.isEnabled(closedLoopPrompt), isFalse);
    });

    test('enabling a tool by name wins over disabled categories', () {
      const configuration = CockpitMcpFeatureConfiguration(
        enabledNames: <String>{'run_task'},
        disabledNames: <String>{'execution'},
      );

      expect(configuration.isEnabled(executionDefinition), isTrue);
    });

    test('enabling a prompt by name wins over disabled categories', () {
      const configuration = CockpitMcpFeatureConfiguration(
        enabledNames: <String>{'run_closed_loop_task'},
        disabledNames: <String>{'workflow_prompts'},
      );

      expect(configuration.isEnabled(closedLoopPrompt), isTrue);
    });
  });
}
