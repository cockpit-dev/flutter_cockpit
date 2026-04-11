import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../control_core/cockpit_intent.dart';
import '../control_core/cockpit_intent_subject.dart';
import '../control_core/cockpit_plane_router.dart';

final class CockpitFlutterSemanticPlane implements CockpitControlPlane {
  const CockpitFlutterSemanticPlane();

  @override
  CockpitPlaneKind get planeKind => CockpitPlaneKind.flutterSemanticPlane;

  @override
  bool supports(CockpitIntent intent) {
    return intent.subject == CockpitIntentSubject.surface ||
        intent.subject == CockpitIntentSubject.app;
  }
}
