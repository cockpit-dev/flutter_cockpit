import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_server_runtime.dart';
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

  test('serve-mcp forwards runtime configuration to the MCP server', () async {
    CockpitMcpServerRuntimeOptions? capturedOptions;
    Sink<String>? capturedSink;
    final tempDir = await Directory.systemTemp.createTemp('serve_mcp_command');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final logPath = '${tempDir.path}/protocol.log';

    final runner = CommandRunner<int>(
      'flutter_cockpit_devtools',
      'Host-side tooling for flutter_cockpit.',
    )..addCommand(
        ServeMcpCommand(
          runtime: CockpitMcpServerRuntime(
            serverFactory: (options) {
              capturedOptions = options;
              return CockpitMcpServer(tools: const []);
            },
            serve: (server, {protocolLogSink}) async {
              capturedSink = protocolLogSink;
              protocolLogSink?.add('protocol-log');
            },
          ),
        ),
      );

    final exitCode = await runner.run(<String>[
          'serve-mcp',
          '--enable',
          'workspace',
          '--disable',
          'execution',
          '--force-roots-fallback',
          '--workspace-root',
          '/workspace',
          '--goals-file',
          'GOALS.md',
          '--skill-contract-file',
          'docs/contracts/flutter-cockpit-skill-contract.md',
          '--bundle-contract-file',
          'docs/contracts/task-run-bundle.md',
          '--log-file',
          logPath,
        ]) ??
        0;

    expect(exitCode, 0);
    expect(capturedOptions?.enabledNames, <String>{'workspace'});
    expect(capturedOptions?.disabledNames, <String>{'execution'});
    expect(capturedOptions?.forceRootsFallback, isTrue);
    expect(capturedOptions?.workspaceRoots, <String>['/workspace']);
    expect(capturedSink, isNotNull);
    expect(File(logPath).readAsStringSync(), contains('protocol-log'));
  });
}
