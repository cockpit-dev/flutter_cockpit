import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_prompt.dart';
import '../core/cockpit_mcp_prompt_definition.dart';

final class CockpitCreateProjectWithValidationPrompt extends CockpitMcpPrompt {
  const CockpitCreateProjectWithValidationPrompt();

  @override
  CockpitMcpPromptDefinition get definition => const CockpitMcpPromptDefinition(
        name: 'create_project_with_validation',
        description:
            'Create a new Dart or Flutter project and bring it to a clean baseline.',
        arguments: <CockpitMcpPromptArgument>[
          CockpitMcpPromptArgument(name: 'project_type', required: true),
          CockpitMcpPromptArgument(name: 'project_name', required: true),
          CockpitMcpPromptArgument(name: 'target_root', required: true),
        ],
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.workspace,
          CockpitMcpFeatureCategory.workflowPrompts,
          CockpitMcpFeatureCategory.projectScaffolding,
        ],
      );

  @override
  Future<CockpitMcpPromptResult> build(Map<String, Object?> arguments) async {
    return CockpitMcpPromptResult(
      messages: <CockpitMcpPromptMessage>[
        CockpitMcpPromptMessage.user(
          'Create the project under `${arguments['target_root']}`, then run the '
          'standard workspace quality flow: analyze, format, test, and apply '
          'safe fixes when appropriate before reporting the project ready.',
        ),
      ],
    );
  }
}
