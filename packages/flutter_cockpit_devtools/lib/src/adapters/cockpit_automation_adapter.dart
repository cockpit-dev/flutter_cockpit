import 'package:flutter_cockpit/flutter_cockpit.dart';

abstract interface class CockpitAutomationAdapter {
  Future<CockpitCapabilities> describeCapabilities();

  Future<CockpitCommandExecution> execute(CockpitCommand command);
}
