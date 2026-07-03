import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

abstract interface class CockpitRecordingAdapter {
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  );

  Future<CockpitRecordingResult> stopRecording();
}
