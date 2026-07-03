import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

abstract interface class CockpitPlatformDriver {
  String get platform;

  Future<CockpitCapabilityProfile> describeCapabilities();
}
