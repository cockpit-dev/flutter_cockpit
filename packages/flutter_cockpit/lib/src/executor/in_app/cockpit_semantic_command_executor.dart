import '../../control/cockpit_command.dart';
import '../../control/cockpit_command_execution.dart';
import '../../control/cockpit_command_type.dart';
import 'cockpit_command_router.dart';

final class CockpitSemanticCommandExecutor {
  const CockpitSemanticCommandExecutor({
    required this.tap,
    required this.longPress,
    required this.doubleTap,
    required this.showOnScreen,
    required this.increase,
    required this.decrease,
    required this.dismiss,
  });

  final CockpitInAppCommandHandler tap;
  final CockpitInAppCommandHandler longPress;
  final CockpitInAppCommandHandler doubleTap;
  final CockpitInAppCommandHandler showOnScreen;
  final CockpitInAppCommandHandler increase;
  final CockpitInAppCommandHandler decrease;
  final CockpitInAppCommandHandler dismiss;

  Future<CockpitCommandExecution> execute(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) {
    return switch (command.commandType) {
      CockpitCommandType.tap => tap(command, stopwatch),
      CockpitCommandType.longPress => longPress(command, stopwatch),
      CockpitCommandType.doubleTap => doubleTap(command, stopwatch),
      CockpitCommandType.showOnScreen => showOnScreen(command, stopwatch),
      CockpitCommandType.increase => increase(command, stopwatch),
      CockpitCommandType.decrease => decrease(command, stopwatch),
      CockpitCommandType.dismiss => dismiss(command, stopwatch),
      _ => throw UnsupportedError(
          'Unsupported semantic command ${command.commandType.name}.',
        ),
    };
  }
}
