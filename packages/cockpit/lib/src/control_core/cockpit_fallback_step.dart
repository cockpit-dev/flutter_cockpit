import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

final class CockpitFallbackStep {
  const CockpitFallbackStep({
    required this.fromPlane,
    required this.toPlane,
    required this.reason,
  });

  final CockpitPlaneKind fromPlane;
  final CockpitPlaneKind toPlane;
  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'fromPlane': fromPlane.name,
    'toPlane': toPlane.name,
    'reason': reason,
  };
}
