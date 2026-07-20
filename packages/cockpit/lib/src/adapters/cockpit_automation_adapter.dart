import 'package:cockpit_protocol/cockpit_protocol.dart';

abstract interface class CockpitAutomationAdapter {
  Future<CockpitCapabilities> describeCapabilities();

  Future<CockpitCommandExecution> execute(CockpitCommand command);
}
