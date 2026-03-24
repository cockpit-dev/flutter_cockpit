import 'package:args/command_runner.dart';

import '../../mcp/cockpit_mcp_server.dart';
import '../cockpit_command_runner.dart';

typedef CockpitMcpServeFunction = Future<void> Function();

final class ServeMcpCommand extends Command<int> {
  ServeMcpCommand({CockpitMcpServer? server, CockpitMcpServeFunction? serve})
      : _serve = serve ?? (server ?? CockpitMcpServer.standard()).serveStdio;

  final CockpitMcpServeFunction _serve;

  @override
  String get name => 'serve-mcp';

  @override
  String get description =>
      'Start the flutter_cockpit_devtools MCP server over stdio.';

  @override
  Future<int> run() async {
    await _serve();
    return cockpitSuccessExitCode;
  }
}
