import '../../control/cockpit_command.dart';
import '../../control/cockpit_command_execution.dart';
import '../../control/cockpit_command_type.dart';

typedef CockpitInAppCommandHandler = Future<CockpitCommandExecution> Function(
  CockpitCommand command,
  Stopwatch stopwatch,
);

final class CockpitCommandRouter {
  const CockpitCommandRouter({
    required Map<CockpitCommandType, CockpitInAppCommandHandler> handlers,
  }) : _handlers = handlers;

  final Map<CockpitCommandType, CockpitInAppCommandHandler> _handlers;

  Future<CockpitCommandExecution> execute(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) {
    final handler = _handlers[command.commandType];
    if (handler == null) {
      throw UnsupportedError(
        'No in-app handler registered for ${command.commandType.name}.',
      );
    }
    return handler(command, stopwatch);
  }
}
