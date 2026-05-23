import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_intent.dart';

abstract interface class CockpitControlPlane {
  CockpitPlaneKind get planeKind;

  bool supports(CockpitIntent intent);
}

final class CockpitPlaneRouter {
  CockpitPlaneRouter({
    Iterable<CockpitControlPlane> planes = const <CockpitControlPlane>[],
  }) : _planes = <CockpitPlaneKind, CockpitControlPlane>{
         for (final plane in planes) plane.planeKind: plane,
       };

  final Map<CockpitPlaneKind, CockpitControlPlane> _planes;

  CockpitControlPlane? planeFor(CockpitPlaneKind planeKind) {
    return _planes[planeKind];
  }
}
