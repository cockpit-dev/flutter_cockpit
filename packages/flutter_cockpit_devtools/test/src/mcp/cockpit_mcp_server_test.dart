import 'dart:io';

import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'standard server registers AI-first app and workspace tools',
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
          'list_targets',
          'launch_app',
          'list_apps',
          'hot_reload',
          'hot_restart',
          'stop_app',
          'read_app',
          'inspect_ui',
          'run_command',
          'run_batch',
          'wait_idle',
          'start_recording',
          'stop_recording',
          'read_logs',
          'read_network',
          'read_errors',
          'pub_dev_search',
          'pub',
          'read_package_uris',
          'lsp',
          'analyze_files',
          'create_project',
          'analyze_workspace',
          'format_workspace',
          'run_tests',
          'apply_fixes',
          'run_script',
          'run_task',
          'validate_task',
        ]),
      );
    },
  );

  test('standard server exposes concise profile parameter names', () async {
    final server = CockpitMcpServer.standard();

    final listResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 99,
      'method': 'tools/list',
    });

    final tools = ((listResponse?['result'] as Map<String, Object?>)['tools']
            as List<Object?>)
        .cast<Map<String, Object?>>();
    final byName = <String, Map<String, Object?>>{
      for (final tool in tools) tool['name']! as String: tool,
    };

    final readAppProperties = ((byName['read_app']!['inputSchema']
            as Map<String, Object?>)['properties'] as Map<String, Object?>)
        .keys;
    expect(readAppProperties, contains('profile'));
    expect(readAppProperties, isNot(contains('resultProfile')));

    final runBatchProperties = ((byName['run_batch']!['inputSchema']
            as Map<String, Object?>)['properties'] as Map<String, Object?>)
        .keys;
    expect(runBatchProperties,
        containsAll(<String>['defaultProfile', 'finalProfile']));
    expect(
      runBatchProperties,
      isNot(containsAll(
          <String>['defaultResultProfile', 'finalSnapshotProfile'])),
    );
  });

  test('standard server exposes app-first resources with snake_case templates',
      () async {
    final server = CockpitMcpServer.standard();

    final fixedResourcesResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'resources/list',
    });
    final fixedResources = ((fixedResourcesResponse?['result']
            as Map<String, Object?>)['resources'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final fixedNames = fixedResources
        .map((resource) => resource['name'])
        .toList(growable: false);

    expect(
        fixedNames,
        containsAll(<String>[
          'workspace_skill_contract',
          'workspace_task_bundle_contract',
          'workspaceRoots',
          'apps',
          'latest_task',
          'workspace_capabilities',
        ]));
    expect(fixedNames, isNot(contains('workspace_goals')));
    expect(fixedNames, isNot(contains('active_sessions')));

    final templateResourcesResponse = await server.handleMessage(
      <String, Object?>{
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'resources/templates/list',
      },
    );
    final templateResources = ((templateResourcesResponse?['result']
            as Map<String, Object?>)['resourceTemplates'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final templateMap = <String, String>{
      for (final resource in templateResources)
        resource['name']! as String: resource['uriTemplate']! as String,
    };

    expect(templateMap['app'], 'cockpit://app/details{?appId}');
    expect(
      templateMap['task_bundleSummary'],
      'cockpit://task/summary{?bundleDir}',
    );
    expect(
      templateMap['package_uri'],
      'cockpit://package/read{?workspaceRoot,uri}',
    );
    expect(templateMap.containsKey('developmentSession'), isFalse);
  });

  test('standard server exposes workspace_goals only when configured',
      () async {
    final server = CockpitMcpServer.standard(goalsFilePath: '/tmp/GOALS.md');

    final fixedResourcesResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 11,
      'method': 'resources/list',
    });
    final fixedResources = ((fixedResourcesResponse?['result']
            as Map<String, Object?>)['resources'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final fixedNames = fixedResources
        .map((resource) => resource['name'])
        .toList(growable: false);

    expect(fixedNames, contains('workspace_goals'));
  });

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

  test('standard server resolves workspace contracts from workspace roots',
      () async {
    final currentDir = Directory.current.path;
    final repoRoot = File(
      p.join(
        currentDir,
        'docs',
        'contracts',
        'flutter-cockpit-skill-contract.md',
      ),
    ).existsSync()
        ? currentDir
        : p.normalize(
            p.join(
              currentDir,
              '..',
              '..',
            ),
          );
    final server = CockpitMcpServer.standard(
      workspaceRoots: <String>[repoRoot],
    );

    await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 199,
      'method': 'initialize',
      'params': <String, Object?>{'protocolVersion': '2024-11-05'},
    });

    final resourceResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 200,
      'method': 'resources/read',
      'params': <String, Object?>{
        'uri': 'cockpit://workspace/skill-contract',
      },
    });

    final result = resourceResponse?['result'] as Map<String, Object?>;
    final contents =
        (result['contents'] as List<Object?>).cast<Map<String, Object?>>();
    expect('${contents.single['text']}', contains('launch-app'));
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
