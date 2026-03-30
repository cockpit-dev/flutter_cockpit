import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:test/test.dart';

void main() {
  test(
    'standard server registers development-session tools alongside validation tools',
    () async {
      final server = CockpitMcpServer.standard();

      final listResponse = await server.handleMessage(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'tools/list',
      });

      final result = listResponse?['result'] as Map<String, Object?>;
      final tools = (result['tools'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .map((tool) => tool['name'])
          .toList(growable: false);
      expect(
        tools,
        containsAll(<String>[
          'add_roots',
          'remove_roots',
          'launch_development_session',
          'query_development_session',
          'reload_development_session',
          'stop_development_session',
          'collect_development_probe',
          'compare_development_probe',
          'collect_remote_snapshot',
          'pub_dev_search',
          'read_package_uris',
          'create_project',
          'analyze_workspace',
          'format_workspace',
          'run_workspace_tests',
          'apply_workspace_fixes',
          'list_launch_targets',
          'list_active_sessions',
          'read_session_logs',
          'read_runtime_errors',
          'validate_task',
        ]),
      );
    },
  );

  test('server initializes, lists tools, and dispatches tool calls', () async {
    final server = CockpitMcpServer(
      tools: <CockpitMcpTool>[
        _FakeCockpitMcpTool(name: 'echo_tool'),
        _FakeCockpitMcpTool(name: 'second_tool'),
        _FakeCockpitMcpTool(name: 'run_task'),
      ],
      serverName: 'flutter_cockpit_devtools',
      serverVersion: '1.0.0',
    );

    final initializeResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': <String, Object?>{'protocolVersion': '2024-11-05'},
    });
    final initializeResult =
        initializeResponse?['result'] as Map<String, Object?>;
    expect(
      initializeResult['capabilities'],
      <String, Object?>{
        'tools': <String, Object?>{},
        'resources': <String, Object?>{},
        'prompts': <String, Object?>{},
        'roots': <String, Object?>{'listChanged': true},
      },
    );

    final listResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 2,
      'method': 'tools/list',
    });
    final listResult = listResponse?['result'] as Map<String, Object?>;
    final tools = listResult['tools'] as List<Object?>;
    expect(tools, hasLength(3));
    expect(
      tools
          .cast<Map<String, Object?>>()
          .map((tool) => tool['name'])
          .toList(growable: false),
      containsAll(<String>['echo_tool', 'second_tool', 'run_task']),
    );

    final promptsResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 20,
      'method': 'prompts/list',
    });
    final promptsResult = promptsResponse?['result'] as Map<String, Object?>;
    expect(promptsResult['prompts'], isEmpty);

    final callResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 3,
      'method': 'tools/call',
      'params': <String, Object?>{
        'name': 'echo_tool',
        'arguments': <String, Object?>{'value': 'hello'},
      },
    });
    final callResult = callResponse?['result'] as Map<String, Object?>;
    expect(
      (callResult['structuredContent'] as Map<String, Object?>)['echoedValue'],
      'hello',
    );
  });
}

final class _FakeCockpitMcpTool extends CockpitMcpTool {
  _FakeCockpitMcpTool({required this.name});

  @override
  final String name;

  @override
  String get description => 'fake';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'value': <String, Object?>{'type': 'string'},
        },
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    return <String, Object?>{
      'content': <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': 'ok'},
      ],
      'structuredContent': <String, Object?>{'echoedValue': arguments['value']},
    };
  }
}
