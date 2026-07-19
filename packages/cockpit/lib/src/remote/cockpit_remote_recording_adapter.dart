import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../adapters/cockpit_recording_adapter.dart';
import 'cockpit_remote_session_client.dart';

final class CockpitRemoteRecordingAdapter
    implements CockpitRecordingAdapter, CockpitRecordingProvenanceProvider {
  CockpitRemoteRecordingAdapter({required CockpitRemoteSessionClient client})
    : _client = client;

  final CockpitRemoteSessionClient _client;

  @override
  CockpitRecordingProvenance get recordingProvenance =>
      const CockpitRecordingProvenance(
        implementation: 'remote',
        sourcePlane: CockpitRecordingSourcePlane.app,
      );

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    return _client.startRecording(request);
  }

  @override
  Future<CockpitRecordingResult> stopRecording() {
    return _client.stopRecording();
  }
}
