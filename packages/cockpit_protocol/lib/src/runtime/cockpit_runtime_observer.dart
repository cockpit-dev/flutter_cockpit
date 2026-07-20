import 'cockpit_runtime_query.dart';
import 'cockpit_runtime_snapshot.dart';

abstract interface class CockpitRuntimeObserver {
  CockpitRuntimeSnapshot snapshot({
    int maxEntries = 8,
    CockpitRuntimeQuery query = const CockpitRuntimeQuery(),
  });

  void clear();

  void dispose();
}
