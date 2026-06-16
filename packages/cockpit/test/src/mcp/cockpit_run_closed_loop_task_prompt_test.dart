import 'package:cockpit/src/mcp/prompts/cockpit_run_closed_loop_task_prompt.dart';
import 'package:test/test.dart';

void main() {
  test(
    'closed-loop prompt relies on contracts instead of workspace goals',
    () async {
      const prompt = CockpitRunClosedLoopTaskPrompt();

      final result = await prompt.build(<String, Object?>{
        'taskGoal': 'Ship the feature with evidence.',
      });

      expect(result.messages, hasLength(1));
      final text = result.messages.single.text;
      expect(text, contains('cockpit://workspace/protocol'));
      expect(text, contains('specific contract resource'));
      expect(text, isNot(contains('cockpit://workspace/goals')));
    },
  );

  test(
    'closed-loop prompt prefers handle reuse and bounded summary reads',
    () async {
      const prompt = CockpitRunClosedLoopTaskPrompt();

      final result = await prompt.build(<String, Object?>{
        'taskGoal': 'Resolve sync conflicts with evidence.',
      });

      final text = result.messages.single.text;
      expect(text, contains('reuse the persisted app or target handle'));
      expect(
        text,
        contains('prefer bounded summary reads before full inspection'),
      );
      expect(text, contains('do not blindly replay a non-idempotent batch'));
      expect(text, contains('re-read minimal route or state before retrying'));
      expect(text, contains('validate the outcome'));
    },
  );
}
