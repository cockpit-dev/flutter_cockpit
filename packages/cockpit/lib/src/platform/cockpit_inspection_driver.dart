import 'package:cockpit_protocol/cockpit_protocol.dart';

abstract interface class CockpitInspectionDriver {
  Future<CockpitSnapshot> inspect(CockpitSnapshotOptions options);
}
