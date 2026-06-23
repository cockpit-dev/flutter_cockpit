import '../../control/cockpit_command.dart';
import '../../control/cockpit_command_execution.dart';
import '../../control/cockpit_command_type.dart';

typedef CockpitInAppCommandHandler =
    Future<CockpitCommandExecution> Function(
      CockpitCommand command,
      Stopwatch stopwatch,
    );

final class CockpitCommandRouter {
  CockpitCommandRouter({
    required Map<CockpitCommandType, CockpitInAppCommandHandler> handlers,
  }) : _handlers = <String, CockpitInAppCommandHandler>{
         for (final entry in handlers.entries) entry.key.name: entry.value,
       };

  final Map<String, CockpitInAppCommandHandler> _handlers;

  Future<CockpitCommandExecution> execute(
    CockpitCommand command,
    Stopwatch stopwatch,
  ) {
    final handler = _handlers[command.commandType.name];
    if (handler == null) {
      throw UnsupportedError(
        'No in-app handler registered for ${command.commandType.name}.',
      );
    }
    return handler(command, stopwatch);
  }
}
