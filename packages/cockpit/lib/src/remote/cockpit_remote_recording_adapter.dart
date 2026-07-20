import 'package:cockpit_protocol/cockpit_protocol.dart';

import '../adapters/cockpit_recording_adapter.dart';
import 'cockpit_remote_session_client.dart';

final class CockpitRemoteRecordingAdapter implements CockpitRecordingAdapter {
  CockpitRemoteRecordingAdapter({required CockpitRemoteSessionClient client})
    : _client = client;

  final CockpitRemoteSessionClient _client;

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
