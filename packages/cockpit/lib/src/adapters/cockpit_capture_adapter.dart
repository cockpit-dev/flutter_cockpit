import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

abstract interface class CockpitCaptureAdapter {
  Future<CockpitCommandExecution> capture(CockpitCommand command);
}
