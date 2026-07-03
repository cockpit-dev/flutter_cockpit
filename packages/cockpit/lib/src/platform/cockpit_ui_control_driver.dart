import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

abstract interface class CockpitUiControlDriver {
  Future<CockpitCommandExecution> execute(CockpitCommand command);
}
