import 'package:flutter_cockpit/flutter_cockpit.dart';

abstract interface class CockpitCaptureAdapter {
  Future<CockpitCommandExecution> capture(CockpitCommand command);
}
