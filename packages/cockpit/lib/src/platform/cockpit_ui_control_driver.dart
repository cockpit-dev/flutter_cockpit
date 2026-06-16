import 'package:flutter_cockpit/flutter_cockpit.dart';

abstract interface class CockpitUiControlDriver {
  Future<CockpitCommandExecution> execute(CockpitCommand command);
}
