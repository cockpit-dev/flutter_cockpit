import '../core/cockpit_mcp_feature_category.dart';
import '../core/cockpit_mcp_prompt.dart';
import '../core/cockpit_mcp_prompt_definition.dart';

final class CockpitRunClosedLoopTaskPrompt extends CockpitMcpPrompt {
  const CockpitRunClosedLoopTaskPrompt();

  @override
  CockpitMcpPromptDefinition get definition => const CockpitMcpPromptDefinition(
    name: 'run_closed_loop_task',
    description: 'Run a full flutter_cockpit closed-loop task with evidence.',
    arguments: <CockpitMcpPromptArgument>[
      CockpitMcpPromptArgument(name: 'taskGoal', required: true),
      CockpitMcpPromptArgument(name: 'platform'),
      CockpitMcpPromptArgument(name: 'requiresVideo'),
    ],
    categories: <CockpitMcpFeatureCategory>[
      CockpitMcpFeatureCategory.closedLoop,
      CockpitMcpFeatureCategory.workflowPrompts,
    ],
  );

  @override
  Future<CockpitMcpPromptResult> build(Map<String, Object?> arguments) async {
    final taskGoal = arguments['taskGoal'] ?? '';
    return CockpitMcpPromptResult(
      messages: <CockpitMcpPromptMessage>[
        CockpitMcpPromptMessage.user(
          'Read `cockpit://workspace/skill-contract`, '
          '`cockpit://workspace/task-bundle-contract`, and '
          '`cockpit://workspace/control-workflow-protocol` for scripted '
          'flows, plus '
          '`cockpit://workspace/capabilities` before acting. Then reuse the '
          'persisted app or target handle whenever possible, prefer bounded '
          'summary reads before full inspection, and if a remote session goes '
          'temporarily unavailable after a mutating or route-changing step, '
          're-read minimal route or state before retrying, do not blindly '
          'replay a non-idempotent batch, and resume from the smallest '
          'remaining step. Then collect baseline evidence, execute the task, '
          'inspect the resulting bundle, validate the outcome, and only claim '
          'success after evidence-backed completion. Task goal: $taskGoal',
        ),
      ],
    );
  }
}
