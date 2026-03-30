import '../../control/cockpit_command.dart';
import '../../control/cockpit_command_execution.dart';
import '../../control/cockpit_command_type.dart';
import 'cockpit_command_router.dart';

final class CockpitWaitAndAssertExecutor {
  const CockpitWaitAndAssertExecutor({
    required this.scrollUntilVisible,
    required this.waitForNetworkIdle,
    required this.waitForUiIdle,
    required this.assertVisible,
    required this.assertText,
    required this.waitFor,
  });

  final CockpitInAppCommandHandler scrollUntilVisible;
  final CockpitInAppCommandHandler waitForNetworkIdle;
  final CockpitInAppCommandHandler waitForUiIdle;
  final CockpitInAppCommandHandler assertVisible;
  final CockpitInAppCommandHandler assertText;
  final CockpitInAppCommandHandler waitFor;

  Future<CockpitCommandExecution> execute(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) {
    return switch (command.commandType) {
      CockpitCommandType.scrollUntilVisible =>
        scrollUntilVisible(command, stopwatch),
      CockpitCommandType.waitForNetworkIdle =>
        waitForNetworkIdle(command, stopwatch),
      CockpitCommandType.waitForUiIdle => waitForUiIdle(command, stopwatch),
      CockpitCommandType.assertVisible => assertVisible(command, stopwatch),
      CockpitCommandType.assertText => assertText(command, stopwatch),
      CockpitCommandType.waitFor => waitFor(command, stopwatch),
      _ => throw UnsupportedError(
          'Unsupported wait/assert command ${command.commandType.name}.',
        ),
    };
  }
}
