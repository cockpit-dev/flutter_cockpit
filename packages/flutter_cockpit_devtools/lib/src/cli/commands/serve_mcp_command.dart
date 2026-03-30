import 'package:args/command_runner.dart';

import '../../mcp/cockpit_mcp_server.dart';
import '../../mcp/cockpit_mcp_server_runtime.dart';
import '../cockpit_command_runner.dart';

typedef CockpitMcpServeFunction = Future<void> Function();

final class ServeMcpCommand extends Command<int> {
  ServeMcpCommand({
    CockpitMcpServer? server,
    CockpitMcpServeFunction? serve,
    CockpitMcpServerRuntime? runtime,
  })  : _serve = serve,
        _server = server,
        _runtime = runtime ?? CockpitMcpServerRuntime() {
    final parser = CockpitMcpServerRuntime.createArgParser();
    for (final option in parser.options.entries) {
      final name = option.key;
      final value = option.value;
      if (value.isFlag) {
        argParser.addFlag(
          name,
          abbr: value.abbr,
          help: value.help,
          defaultsTo: value.defaultsTo,
          negatable: value.negatable ?? true,
        );
      } else if (value.isMultiple) {
        argParser.addMultiOption(
          name,
          abbr: value.abbr,
          help: value.help,
          defaultsTo: value.defaultsTo as List<String>?,
        );
      } else {
        argParser.addOption(
          name,
          abbr: value.abbr,
          help: value.help,
          defaultsTo: value.defaultsTo as String?,
        );
      }
    }
  }

  final CockpitMcpServeFunction? _serve;
  final CockpitMcpServer? _server;
  final CockpitMcpServerRuntime _runtime;

  @override
  String get name => 'serve-mcp';

  @override
  String get description =>
      'Start the flutter_cockpit_devtools MCP server over stdio.';

  @override
  Future<int> run() async {
    if (_serve case final serve?) {
      await serve();
    } else if (_server case final server?) {
      await server.serveStdio();
    } else {
      await _runtime.run(argResults!);
    }
    return cockpitSuccessExitCode;
  }
}
