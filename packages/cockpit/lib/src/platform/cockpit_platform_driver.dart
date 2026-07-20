import 'package:cockpit_protocol/cockpit_protocol.dart';

abstract interface class CockpitPlatformDriver {
  String get platform;

  Future<CockpitCapabilityProfile> describeCapabilities();
}
