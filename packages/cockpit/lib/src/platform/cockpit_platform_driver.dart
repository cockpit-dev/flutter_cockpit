import 'package:flutter_cockpit/flutter_cockpit.dart';

abstract interface class CockpitPlatformDriver {
  String get platform;

  Future<CockpitCapabilityProfile> describeCapabilities();
}
