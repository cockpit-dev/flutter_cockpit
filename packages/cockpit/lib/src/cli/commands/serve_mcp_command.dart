import 'package:args/command_runner.dart';

import '../../mcp/cockpit_mcp_server.dart';
import '../cockpit_cli_runtime.dart';

final class CockpitServeMcpCommand extends Command<int> {
  CockpitServeMcpCommand({CockpitMcpServer? server})
    : _server = server ?? CockpitMcpServer.standard();

  final CockpitMcpServer _server;

  @override
  String get name => 'serve-mcp';

  @override
  String get description => 'Serve the Cockpit 2.0 MCP transport over stdio.';

  @override
  Future<int> run() async {
    await _server.serveStdio();
    return cockpitSuccessExitCode;
  }
}
