import 'package:flutter_cockpit/flutter_cockpit.dart';

abstract interface class CockpitRecordingAdapter {
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  );

  Future<CockpitRecordingResult> stopRecording();
}
