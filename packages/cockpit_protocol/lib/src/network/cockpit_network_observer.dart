import 'cockpit_network_query.dart';
import 'cockpit_network_snapshot.dart';

abstract interface class CockpitNetworkObserver {
  CockpitNetworkSnapshot snapshot({
    int maxEntries = 10,
    CockpitNetworkQuery query = const CockpitNetworkQuery(),
  });

  Future<bool> waitForIdle({
    Duration quietWindow = const Duration(milliseconds: 150),
    Duration timeout = const Duration(seconds: 2),
  });

  void clear();
}
