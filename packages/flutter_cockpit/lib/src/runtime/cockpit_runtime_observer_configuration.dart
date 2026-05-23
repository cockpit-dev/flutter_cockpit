import 'cockpit_flutter_runtime_observer.dart';

final class CockpitRuntimeObserverConfiguration {
  const CockpitRuntimeObserverConfiguration({
    this.enabled = true,
    this.captureDebugPrint = true,
    this.capturePrint = true,
    this.maxRetainedEvents = 120,
    this.maxMessageLength = 512,
    this.maxDetailLength = 512,
    this.maxStackTraceLines = 12,
  });

  final bool enabled;
  final bool captureDebugPrint;
  final bool capturePrint;
  final int maxRetainedEvents;
  final int maxMessageLength;
  final int maxDetailLength;
  final int maxStackTraceLines;

  CockpitFlutterRuntimeObserver buildObserver({
    required CockpitRuntimeCurrentRouteProvider routeNameProvider,
    CockpitRuntimeCriticalEventHandler? onCriticalEvent,
  }) {
    return CockpitFlutterRuntimeObserver(
      routeNameProvider: routeNameProvider,
      onCriticalEvent: onCriticalEvent,
      captureDebugPrint: captureDebugPrint,
      capturePrint: capturePrint,
      maxRetainedEvents: maxRetainedEvents,
      maxMessageLength: maxMessageLength,
      maxDetailLength: maxDetailLength,
      maxStackTraceLines: maxStackTraceLines,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is CockpitRuntimeObserverConfiguration &&
            other.enabled == enabled &&
            other.captureDebugPrint == captureDebugPrint &&
            other.capturePrint == capturePrint &&
            other.maxRetainedEvents == maxRetainedEvents &&
            other.maxMessageLength == maxMessageLength &&
            other.maxDetailLength == maxDetailLength &&
            other.maxStackTraceLines == maxStackTraceLines;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    captureDebugPrint,
    capturePrint,
    maxRetainedEvents,
    maxMessageLength,
    maxDetailLength,
    maxStackTraceLines,
  );
}
