import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../control_core/cockpit_intent.dart';
import '../control_core/cockpit_intent_subject.dart';
import '../control_core/cockpit_plane_router.dart';

final class CockpitDeviceSystemPlane implements CockpitControlPlane {
  const CockpitDeviceSystemPlane();

  @override
  CockpitPlaneKind get planeKind => CockpitPlaneKind.deviceSystemPlane;

  @override
  bool supports(CockpitIntent intent) {
    return intent.subject != CockpitIntentSubject.host;
  }
}
