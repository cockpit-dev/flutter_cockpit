import 'package:cockpit_protocol/cockpit_protocol.dart';

abstract interface class CockpitUiControlDriver {
  Future<CockpitCommandExecution> execute(CockpitCommand command);
}
