import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_prompt.dart';
import '../core/cockpit_mcp_prompt_definition.dart';

final class CockpitRecoverFromFailedValidationPrompt extends CockpitMcpPrompt {
  const CockpitRecoverFromFailedValidationPrompt();

  @override
  CockpitMcpPromptDefinition get definition => const CockpitMcpPromptDefinition(
        name: 'recover_from_failed_validation',
        description: 'Investigate a blocked or failed validation outcome.',
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.closedLoop,
          CockpitMcpFeatureCategory.workflowPrompts,
        ],
      );

  @override
  Future<CockpitMcpPromptResult> build(Map<String, Object?> arguments) async {
    return const CockpitMcpPromptResult(
      messages: <CockpitMcpPromptMessage>[
        CockpitMcpPromptMessage.user(
          'When validation fails, classify the result explicitly as blocked, '
          'failed, or needing more work. Read the latest task summary, inspect '
          'runtime and network evidence, inspect diagnostics artifact paths, and '
          'use structured evidence to decide the next step instead of guessing.',
        ),
      ],
    );
  }
}
