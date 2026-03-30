import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_prompt.dart';
import '../core/cockpit_mcp_prompt_definition.dart';

final class CockpitPrepareAcceptanceDeliveryPrompt extends CockpitMcpPrompt {
  const CockpitPrepareAcceptanceDeliveryPrompt();

  @override
  CockpitMcpPromptDefinition get definition => const CockpitMcpPromptDefinition(
        name: 'prepare_acceptance_delivery',
        description:
            'Prepare validated artifacts and handoff output for delivery.',
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
          'Use validated screenshot, keyframe, and recording paths from the '
          'bundle summary. Pair them with acceptance markdown and handoff data so '
          'the result is ready for human review or host-level artifact delivery.',
        ),
      ],
    );
  }
}
