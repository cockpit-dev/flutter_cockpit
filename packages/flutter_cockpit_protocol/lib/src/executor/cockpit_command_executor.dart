import '../control/cockpit_command.dart';
import '../control/cockpit_command_result.dart';
import '../runtime/cockpit_capabilities.dart';

abstract interface class CockpitCommandExecutor {
  Future<CockpitCapabilities> describeCapabilities();

  Future<CockpitCommandResult> execute(CockpitCommand command);
}
