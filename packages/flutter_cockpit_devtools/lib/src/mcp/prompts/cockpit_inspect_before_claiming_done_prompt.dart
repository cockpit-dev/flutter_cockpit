import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_prompt.dart';
import '../core/cockpit_mcp_prompt_definition.dart';

final class CockpitInspectBeforeClaimingDonePrompt extends CockpitMcpPrompt {
  const CockpitInspectBeforeClaimingDonePrompt();

  @override
  CockpitMcpPromptDefinition get definition => const CockpitMcpPromptDefinition(
    name: 'inspect_before_claiming_done',
    description: 'Check bundle-backed evidence before reporting completion.',
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
          'Before claiming completion, read the latest task resource or task '
          'bundle summary, inspect screenshot and recording readiness, inspect '
          'acceptance evidence and acceptance delta when present, and ensure the '
          'classification is truly `completed`.',
        ),
      ],
    );
  }
}
