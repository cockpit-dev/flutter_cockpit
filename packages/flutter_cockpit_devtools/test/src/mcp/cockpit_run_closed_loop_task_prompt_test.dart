import 'package:flutter_cockpit_devtools/src/mcp/prompts/cockpit_run_closed_loop_task_prompt.dart';
import 'package:test/test.dart';

void main() {
  test('closed-loop prompt relies on contracts instead of workspace goals',
      () async {
    const prompt = CockpitRunClosedLoopTaskPrompt();

    final result = await prompt.build(<String, Object?>{
      'task_goal': 'Ship the feature with evidence.',
    });

    expect(result.messages, hasLength(1));
    final text = result.messages.single.text;
    expect(text, contains('cockpit://workspace/skill-contract'));
    expect(text, contains('cockpit://workspace/task-bundle-contract'));
    expect(text, isNot(contains('cockpit://workspace/goals')));
  });
}
