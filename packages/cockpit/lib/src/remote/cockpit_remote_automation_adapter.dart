import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../adapters/cockpit_automation_adapter.dart';
import 'cockpit_remote_session_client.dart';

final class CockpitRemoteAutomationAdapter implements CockpitAutomationAdapter {
  CockpitRemoteAutomationAdapter({required CockpitRemoteSessionClient client})
    : _client = client;

  final CockpitRemoteSessionClient _client;

  @override
  Future<CockpitCapabilities> describeCapabilities() async {
    return (await _client.readStatus()).capabilities;
  }

  @override
  Future<CockpitCommandExecution> execute(CockpitCommand command) {
    return _client.executeDetailed(command);
  }
}
