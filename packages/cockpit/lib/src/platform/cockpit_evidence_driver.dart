import '../adapters/cockpit_capture_adapter.dart';
import '../adapters/cockpit_recording_adapter.dart';

abstract interface class CockpitEvidenceDriver {
  CockpitCaptureAdapter? get captureAdapter;

  CockpitRecordingAdapter? get recordingAdapter;
}
