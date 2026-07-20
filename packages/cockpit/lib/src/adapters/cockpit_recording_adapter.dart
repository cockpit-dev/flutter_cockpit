import 'package:cockpit_protocol/cockpit_protocol.dart';

enum CockpitRecordingSourcePlane { app, host }

final class CockpitRecordingProvenance {
  const CockpitRecordingProvenance({
    required this.implementation,
    required this.sourcePlane,
  });

  final String implementation;
  final CockpitRecordingSourcePlane sourcePlane;
}

abstract interface class CockpitRecordingProvenanceProvider {
  CockpitRecordingProvenance? get recordingProvenance;
}

abstract interface class CockpitRecordingAdapter {
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  );

  Future<CockpitRecordingResult> stopRecording();
}
