import 'package:cockpit_protocol/cockpit_protocol.dart';

abstract interface class CockpitCaptureAdapter {
  Future<CockpitCommandExecution> capture(CockpitCommand command);
}
