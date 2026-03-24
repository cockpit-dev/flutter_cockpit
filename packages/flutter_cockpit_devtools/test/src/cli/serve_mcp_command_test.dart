import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/cli/commands/serve_mcp_command.dart';
import 'package:test/test.dart';

void main() {
  test('serve-mcp starts the shared MCP server entrypoint', () async {
    var started = false;
    final runner = CommandRunner<int>(
      'flutter_cockpit_devtools',
      'Host-side tooling for flutter_cockpit.',
    )..addCommand(
        ServeMcpCommand(
          serve: () async {
            started = true;
          },
        ),
      );

    final exitCode = await runner.run(<String>['serve-mcp']) ?? 0;

    expect(exitCode, 0);
    expect(started, isTrue);
  });
}
