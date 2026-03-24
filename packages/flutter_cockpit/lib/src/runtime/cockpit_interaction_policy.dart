import 'cockpit_hit_test_miss_policy.dart';

final class CockpitInteractionPolicy {
  const CockpitInteractionPolicy({
    this.targetResolveTimeout = const Duration(milliseconds: 1200),
    this.targetResolvePollInterval = const Duration(milliseconds: 32),
    this.uiIdleQuietWindow = const Duration(milliseconds: 96),
    this.uiIdleTimeout = const Duration(milliseconds: 1600),
    this.preActionVisualDelay = const Duration(milliseconds: 40),
    this.recordingPreActionVisualDelay = const Duration(milliseconds: 120),
    this.actionVisualDelay = const Duration(milliseconds: 48),
    this.routeTransitionVisualDelay = const Duration(milliseconds: 96),
    this.recordingActionVisualDelay = const Duration(milliseconds: 160),
    this.waitForNetworkIdleDuringAcceptanceCapture = true,
    this.hitTestMissPolicy = CockpitHitTestMissPolicy.warn,
  });

  final Duration targetResolveTimeout;
  final Duration targetResolvePollInterval;
  final Duration uiIdleQuietWindow;
  final Duration uiIdleTimeout;
  final Duration preActionVisualDelay;
  final Duration recordingPreActionVisualDelay;
  final Duration actionVisualDelay;
  final Duration routeTransitionVisualDelay;
  final Duration recordingActionVisualDelay;
  final bool waitForNetworkIdleDuringAcceptanceCapture;
  final CockpitHitTestMissPolicy hitTestMissPolicy;

  CockpitInteractionPolicy copyWith({
    Duration? targetResolveTimeout,
    Duration? targetResolvePollInterval,
    Duration? uiIdleQuietWindow,
    Duration? uiIdleTimeout,
    Duration? preActionVisualDelay,
    Duration? recordingPreActionVisualDelay,
    Duration? actionVisualDelay,
    Duration? routeTransitionVisualDelay,
    Duration? recordingActionVisualDelay,
    bool? waitForNetworkIdleDuringAcceptanceCapture,
    CockpitHitTestMissPolicy? hitTestMissPolicy,
  }) {
    return CockpitInteractionPolicy(
      targetResolveTimeout: targetResolveTimeout ?? this.targetResolveTimeout,
      targetResolvePollInterval:
          targetResolvePollInterval ?? this.targetResolvePollInterval,
      uiIdleQuietWindow: uiIdleQuietWindow ?? this.uiIdleQuietWindow,
      uiIdleTimeout: uiIdleTimeout ?? this.uiIdleTimeout,
      preActionVisualDelay: preActionVisualDelay ?? this.preActionVisualDelay,
      recordingPreActionVisualDelay:
          recordingPreActionVisualDelay ?? this.recordingPreActionVisualDelay,
      actionVisualDelay: actionVisualDelay ?? this.actionVisualDelay,
      routeTransitionVisualDelay:
          routeTransitionVisualDelay ?? this.routeTransitionVisualDelay,
      recordingActionVisualDelay:
          recordingActionVisualDelay ?? this.recordingActionVisualDelay,
      waitForNetworkIdleDuringAcceptanceCapture:
          waitForNetworkIdleDuringAcceptanceCapture ??
              this.waitForNetworkIdleDuringAcceptanceCapture,
      hitTestMissPolicy: hitTestMissPolicy ?? this.hitTestMissPolicy,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitInteractionPolicy &&
            other.targetResolveTimeout == targetResolveTimeout &&
            other.targetResolvePollInterval == targetResolvePollInterval &&
            other.uiIdleQuietWindow == uiIdleQuietWindow &&
            other.uiIdleTimeout == uiIdleTimeout &&
            other.preActionVisualDelay == preActionVisualDelay &&
            other.recordingPreActionVisualDelay ==
                recordingPreActionVisualDelay &&
            other.actionVisualDelay == actionVisualDelay &&
            other.routeTransitionVisualDelay == routeTransitionVisualDelay &&
            other.recordingActionVisualDelay == recordingActionVisualDelay &&
            other.waitForNetworkIdleDuringAcceptanceCapture ==
                waitForNetworkIdleDuringAcceptanceCapture &&
            other.hitTestMissPolicy == hitTestMissPolicy;
  }

  @override
  int get hashCode => Object.hash(
        targetResolveTimeout,
        targetResolvePollInterval,
        uiIdleQuietWindow,
        uiIdleTimeout,
        preActionVisualDelay,
        recordingPreActionVisualDelay,
        actionVisualDelay,
        routeTransitionVisualDelay,
        recordingActionVisualDelay,
        waitForNetworkIdleDuringAcceptanceCapture,
        hitTestMissPolicy,
      );
}
