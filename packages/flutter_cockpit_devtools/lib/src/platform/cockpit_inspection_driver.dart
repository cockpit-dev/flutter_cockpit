import 'package:flutter_cockpit/flutter_cockpit.dart';

abstract interface class CockpitInspectionDriver {
  Future<CockpitSnapshot> inspect(CockpitSnapshotOptions options);
}
