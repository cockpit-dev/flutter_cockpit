import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../adapters/cockpit_capture_adapter.dart';
import 'cockpit_remote_session_client.dart';

final class CockpitRemoteCaptureAdapter implements CockpitCaptureAdapter {
  CockpitRemoteCaptureAdapter({required CockpitRemoteSessionClient client})
      : _client = client;

  final CockpitRemoteSessionClient _client;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) {
    return _client.executeDetailed(command);
  }
}
