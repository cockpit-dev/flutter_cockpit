import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_prompt.dart';
import '../core/cockpit_mcp_prompt_definition.dart';

final class CockpitRunClosedLoopTaskPrompt extends CockpitMcpPrompt {
  const CockpitRunClosedLoopTaskPrompt();

  @override
  CockpitMcpPromptDefinition get definition => const CockpitMcpPromptDefinition(
        name: 'run_closed_loop_task',
        description:
            'Run a full flutter_cockpit closed-loop task with evidence.',
        arguments: <CockpitMcpPromptArgument>[
          CockpitMcpPromptArgument(name: 'task_goal', required: true),
          CockpitMcpPromptArgument(name: 'platform'),
          CockpitMcpPromptArgument(name: 'requires_video'),
        ],
        categories: <CockpitMcpFeatureCategory>[
          CockpitMcpFeatureCategory.closedLoop,
          CockpitMcpFeatureCategory.workflowPrompts,
        ],
      );

  @override
  Future<CockpitMcpPromptResult> build(Map<String, Object?> arguments) async {
    final taskGoal = arguments['task_goal'] ?? '';
    return CockpitMcpPromptResult(
      messages: <CockpitMcpPromptMessage>[
        CockpitMcpPromptMessage.user(
          'Read `cockpit://workspace/skill-contract`, '
          '`cockpit://workspace/task-bundle-contract`, and '
          '`cockpit://workspace/capabilities` before acting. Then establish '
          'or reuse a session, collect baseline evidence, execute the task, '
          'inspect the resulting bundle, validate the outcome, and only claim '
          'success after evidence-backed completion. Task goal: $taskGoal',
        ),
      ],
    );
  }
}
