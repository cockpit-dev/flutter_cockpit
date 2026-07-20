import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../adapters/cockpit_recording_adapter.dart';

final class CockpitRecordingStrategyResolution {
  const CockpitRecordingStrategyResolution({
    required this.implementation,
    required this.requestedMode,
    required this.requestedLayer,
    required this.fallbackUsed,
    this.adapter,
    this.effectiveLayer,
    this.fallbackReason,
    this.unsupportedReason,
  });

  final String implementation;
  final CockpitRecordingAdapter? adapter;
  final CockpitRecordingMode requestedMode;
  final CockpitRecordingLayer? requestedLayer;
  final CockpitRecordingLayer? effectiveLayer;
  final bool fallbackUsed;
  final String? fallbackReason;
  final String? unsupportedReason;

  bool get isSupported => adapter != null && effectiveLayer != null;
}
