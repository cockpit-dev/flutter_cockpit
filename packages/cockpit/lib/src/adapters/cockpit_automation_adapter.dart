import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

abstract interface class CockpitAutomationAdapter {
  Future<CockpitCapabilities> describeCapabilities();

  Future<CockpitCommandExecution> execute(CockpitCommand command);
}
