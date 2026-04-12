import 'package:flutter/widgets.dart';

import 'cockpit_discovery_policy.dart';
import 'cockpit_native_target_discovery.dart';
import 'cockpit_target.dart';

final class CockpitDiscoveryEngine {
  const CockpitDiscoveryEngine({this.policy = const CockpitDiscoveryPolicy()});

  final CockpitDiscoveryPolicy policy;

  List<CockpitTarget> discover({
    required BuildContext rootContext,
    required String? routeName,
    List<CockpitTarget> explicitTargets = const <CockpitTarget>[],
    bool allowInactiveRouteFallback = false,
  }) {
    return CockpitNativeTargetDiscovery(policy: policy).discover(
      rootContext: rootContext,
      routeName: routeName,
      explicitTargets: explicitTargets,
      allowInactiveRouteFallback: allowInactiveRouteFallback,
    );
  }
}
