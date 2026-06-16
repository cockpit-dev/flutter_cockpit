import 'dart:isolate';

import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('standard server registers AI-first app and workspace tools', () async {
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
      unorderedEquals(<String>[
        'add_roots',
        'analyze_files',
        'analyze_workspace',
        'apply_fixes',
        'capture_screenshot',
        'collect_development_probe',
        'collect_remote_snapshot',
        'compare_development_probe',
        'create_project',
        'execute_remote_command',
        'execute_remote_command_batch',
        'format_workspace',
        'grep_package_uris',
        'hot_reload',
        'hot_restart',
        'inspect_surface',
        'inspect_ui',
        'launch_app',
        'launch_development_session',
        'launch_remote_session',
        'launch_target',
        'list_active_sessions',
        'list_apps',
        'list_targets',
        'lsp',
        'pub',
        'pub_dev_search',
        'query_development_session',
        'query_remote_session',
        'read_app',
        'read_errors',
        'read_logs',
        'read_network',
        'read_package_uris',
        'read_remote_snapshot',
        'read_remote_status',
        'read_session_logs',
        'read_system_capabilities',
        'read_target',
        'read_task_bundle_summary',
        'reload_development_session',
        'remove_roots',
        'run_batch',
        'run_command',
        'run_shell',
        'run_system_action',
        'run_script',
        'run_task',
        'run_tests',
        'start_recording',
        'start_remote_recording',
        'stop_app',
        'stop_development_session',
        'stop_recording',
        'stop_remote_recording',
        'validate_task',
        'wait_idle',
        'wait_remote_ui_idle',
      ]),
    );
  });

  test('standard server exposes concise profile parameter names', () async {
    final server = CockpitMcpServer.standard();

    final listResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 99,
      'method': 'tools/list',
    });

    final tools =
        ((listResponse?['result'] as Map<String, Object?>)['tools']
                as List<Object?>)
            .cast<Map<String, Object?>>();
    final byName = <String, Map<String, Object?>>{
      for (final tool in tools) tool['name']! as String: tool,
    };

    final readAppProperties =
        ((byName['read_app']!['inputSchema']
                    as Map<String, Object?>)['properties']
                as Map<String, Object?>)
            .keys;
    expect(readAppProperties, contains('profile'));
    expect(readAppProperties, contains('androidDeviceId'));
    expect(readAppProperties, isNot(contains('resultProfile')));

    final runCommandProperties =
        ((byName['run_command']!['inputSchema']
                    as Map<String, Object?>)['properties']
                as Map<String, Object?>)
            .keys;
    expect(
      runCommandProperties,
      containsAll(<String>['androidDeviceId', 'iosDeviceId']),
    );

    final runBatchProperties =
        ((byName['run_batch']!['inputSchema']
                    as Map<String, Object?>)['properties']
                as Map<String, Object?>)
            .keys;
    expect(
      runBatchProperties,
      containsAll(<String>[
        'androidDeviceId',
        'iosDeviceId',
        'defaultProfile',
        'finalProfile',
      ]),
    );
    final startRecordingProperties =
        ((byName['start_recording']!['inputSchema']
                    as Map<String, Object?>)['properties']
                as Map<String, Object?>)
            .keys;
    expect(startRecordingProperties, contains('iosDeviceId'));
    expect(
      (byName['start_recording']!['inputSchema'] as Map<String, Object?>),
      isNot(containsPair('required', contains('recording'))),
    );
    final stopRecordingProperties =
        ((byName['stop_recording']!['inputSchema']
                    as Map<String, Object?>)['properties']
                as Map<String, Object?>)
            .keys;
    expect(stopRecordingProperties, contains('iosDeviceId'));
    expect(
      runBatchProperties,
      isNot(
        containsAll(<String>['defaultResultProfile', 'finalSnapshotProfile']),
      ),
    );
  });

  test(
    'standard server exposes app-first resources with snake_case templates',
    () async {
      final server = CockpitMcpServer.standard();

      final fixedResourcesResponse = await server.handleMessage(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'resources/list',
        },
      );
      final fixedResources =
          ((fixedResourcesResponse?['result']
                      as Map<String, Object?>)['resources']
                  as List<Object?>)
              .cast<Map<String, Object?>>();
      final fixedNames = fixedResources
          .map((resource) => resource['name'])
          .toList(growable: false);

      expect(
        fixedNames,
        containsAll(<String>[
          'workspace_ai_development_protocol',
          'workspace_skill_contract',
          'workspace_task_bundle_contract',
          'workspace_control_workflow_protocol',
          'workspace_control_workflow_schema',
          'workspaceRoots',
          'apps',
          'latest_task',
          'workspace_capabilities',
        ]),
      );
      expect(fixedNames, isNot(contains('workspace_goals')));
      expect(fixedNames, isNot(contains('active_sessions')));

      final templateResourcesResponse = await server.handleMessage(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'resources/templates/list',
        },
      );
      final templateResources =
          ((templateResourcesResponse?['result']
                      as Map<String, Object?>)['resourceTemplates']
                  as List<Object?>)
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
    expect(initializeResult['capabilities'], <String, Object?>{
      'tools': <String, Object?>{},
      'resources': <String, Object?>{},
      'prompts': <String, Object?>{},
      'roots': <String, Object?>{'listChanged': true},
    });

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

  test('tool descriptors always include object schema properties', () async {
    final server = CockpitMcpServer(
      tools: <CockpitMcpTool>[_ToolWithoutProperties()],
    );

    final listResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/list',
    });

    final result = listResponse?['result'] as Map<String, Object?>;
    final tools = (result['tools'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final schema = tools.single['inputSchema'] as Map<String, Object?>;

    expect(schema['type'], 'object');
    expect(schema['properties'], <String, Object?>{});
  });

  test('standard server does not register duplicate tools', () async {
    final server = CockpitMcpServer.standard();

    final listResponse = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/list',
    });

    final result = listResponse?['result'] as Map<String, Object?>;
    final tools = (result['tools'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .map((tool) => tool['name']! as String)
        .toList(growable: false);

    expect(tools.toSet(), hasLength(tools.length));
  });

  test(
    'standard server resolves workspace contracts from workspace roots',
    () async {
      final packageUri = await Isolate.resolvePackageUri(
        Uri.parse(
          'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart',
        ),
      );
      final packageRoot = p.dirname(p.dirname(packageUri!.toFilePath()));
      final repoRoot = p.normalize(p.join(packageRoot, '..', '..'));
      final server = CockpitMcpServer.standard(
        workspaceRoots: <String>[repoRoot],
      );

      await server.handleMessage(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 199,
        'method': 'initialize',
        'params': <String, Object?>{'protocolVersion': '2024-11-05'},
      });

      final protocolResponse = await server.handleMessage(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 198,
        'method': 'resources/read',
        'params': <String, Object?>{'uri': 'cockpit://workspace/protocol'},
      });

      final protocolResult =
          protocolResponse?['result'] as Map<String, Object?>;
      final protocolContents = (protocolResult['contents'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(
        '${protocolContents.single['text']}',
        contains('Flutter Cockpit Protocol'),
      );

      final resourceResponse = await server.handleMessage(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 200,
        'method': 'resources/read',
        'params': <String, Object?>{
          'uri': 'cockpit://workspace/skill-contract',
        },
      });

      final result = resourceResponse?['result'] as Map<String, Object?>;
      final contents = (result['contents'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect('${contents.single['text']}', contains('launch-app'));

      final workflowProtocolResponse = await server.handleMessage(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 201,
          'method': 'resources/read',
          'params': <String, Object?>{
            'uri': 'cockpit://workspace/control-workflow-protocol',
          },
        },
      );

      final workflowResult =
          workflowProtocolResponse?['result'] as Map<String, Object?>;
      final workflowContents = (workflowResult['contents'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(
        '${workflowContents.single['text']}',
        contains('schemaVersion: 1'),
      );

      final workflowSchemaResponse = await server.handleMessage(
        <String, Object?>{
          'jsonrpc': '2.0',
          'id': 202,
          'method': 'resources/read',
          'params': <String, Object?>{
            'uri': 'cockpit://workspace/control-workflow-schema',
          },
        },
      );

      final schemaResult =
          workflowSchemaResponse?['result'] as Map<String, Object?>;
      final schemaContents = (schemaResult['contents'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(
        '${schemaContents.single['text']}',
        contains('"title": "Flutter Cockpit Control Workflow Script"'),
      );
    },
  );
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

final class _ToolWithoutProperties extends CockpitMcpTool {
  @override
  String get name => 'empty_schema_tool';

  @override
  String get description => 'fake';

  @override
  Map<String, Object?> get inputSchema => const <String, Object?>{
    'type': 'object',
  };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    return cockpitMcpResult(
      text: 'ok',
      structuredContent: const <String, Object?>{},
    );
  }
}
