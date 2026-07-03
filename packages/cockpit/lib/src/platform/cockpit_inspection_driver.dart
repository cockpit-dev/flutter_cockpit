import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

abstract interface class CockpitInspectionDriver {
  Future<CockpitSnapshot> inspect(CockpitSnapshotOptions options);
}
