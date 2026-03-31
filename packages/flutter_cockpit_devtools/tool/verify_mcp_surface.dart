import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final verifier = _McpSurfaceVerifier();
  final report = await verifier.run();
  final reportFile = File(p.join(report.verifyRoot, 'mcp_real_verify.json'))
    ..createSync(recursive: true)
    ..writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report.summary),
    );
  stdout.writeln(reportFile.path);
}

final class _VerificationReport {
  const _VerificationReport({
    required this.verifyRoot,
    required this.summary,
  });

  final String verifyRoot;
  final Map<String, Object?> summary;
}

final class _McpSurfaceVerifier {
  _McpSurfaceVerifier()
      : _repoRoot = p.normalize(
          p.join(
            p.dirname(Platform.script.toFilePath()),
            '..',
            '..',
            '..',
          ),
        );

  final String _repoRoot;
  int _requestId = 0;

  Future<_VerificationReport> run() async {
    final verifyDirectory =
        await Directory.systemTemp.createTemp('flutter_cockpit_mcp_real.');
    final workspaceRoot = Directory(
      p.join(verifyDirectory.path, 'workspace'),
    )..createSync(recursive: true);
    final report = <String, Object?>{
      'repo_root': _repoRoot,
      'verify_root': verifyDirectory.path,
    };
    final extraRoot = Directory(p.join(verifyDirectory.path, 'extra_root'))
      ..createSync(recursive: true);
    final workspaceReport = <String, Object?>{};
    final appReport = <String, Object?>{};
    report['workspace_verification'] = workspaceReport;
    report['app_verification'] = appReport;

    final server = CockpitMcpServer.standard(
      forceRootsFallback: true,
      workspaceRoots: <String>[_repoRoot, workspaceRoot.path],
    );

    final appJsonPath = p.join(verifyDirectory.path, 'example_app.json');
    String? appId;

    try {
      report['initialize'] = await _rpc(server, 'initialize', <String, Object?>{
        'protocolVersion': '2024-11-05',
      });
      report['tools'] = await _toolNames(server);
      report['resources'] = await _resourceNames(server);
      report['resource_templates'] = await _resourceTemplateNames(server);
      report['prompts'] = await _promptNames(server);
      report['roots'] = await _roots(server);
      report['roots_mutation'] = <String, Object?>{
        'added': await _callTool(
          server,
          'add_roots',
          <String, Object?>{
            'roots': <Map<String, Object?>>[
              <String, Object?>{
                'uri': Uri.directory(extraRoot.path).toString(),
                'name': p.basename(extraRoot.path),
              },
            ],
          },
        ),
        'after_add': await _roots(server),
        'removed': await _callTool(
          server,
          'remove_roots',
          <String, Object?>{
            'uris': <String>[Uri.directory(extraRoot.path).toString()],
          },
        ),
        'after_remove': await _roots(server),
      };

      report['workspace_resources'] = <String, Object?>{
        'goals': await _readTextResource(server, 'cockpit://workspace/goals'),
        'capabilities': await _readJsonResource(
          server,
          'cockpit://workspace/capabilities',
        ),
      };
      report['prompts_preview'] = await _getPrompt(
        server,
        'run_closed_loop_task',
        <String, Object?>{
          'task_goal': 'Verify the MCP release surface end to end.',
          'platform': 'macos',
          'requires_video': true,
        },
      );

      final createdProject = await _callTool(
        server,
        'create_project',
        <String, Object?>{
          'parent_directory': workspaceRoot.path,
          'project_name': 'mcp_verify_project',
          'template': 'dart_cli',
          'timeout_seconds': 300,
        },
      );
      final projectRoot = createdProject['project_directory']! as String;
      report['workspace_project'] = <String, Object?>{
        'project_root': projectRoot,
      };
      await _prepareWorkspaceProject(projectRoot);

      workspaceReport['pub_dev_search'] = await _callTool(
        server,
        'pub_dev_search',
        <String, Object?>{
          'query': 'collection',
          'max_results': 1,
          'timeout_seconds': 20,
        },
      );
      workspaceReport['pub_get'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'get',
          'timeout_seconds': 240,
        },
      );
      workspaceReport['pub_add'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'add',
          'packages': <String>['collection'],
          'timeout_seconds': 240,
        },
      );
      workspaceReport['pub_deps'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'deps',
          'timeout_seconds': 240,
        },
      );
      workspaceReport['pub_outdated'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'outdated',
          'timeout_seconds': 240,
        },
      );
      workspaceReport['pub_upgrade'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'upgrade',
          'timeout_seconds': 240,
        },
      );
      workspaceReport['package_uri_tool'] = await _callTool(
        server,
        'read_package_uris',
        <String, Object?>{
          'workspace_root': projectRoot,
          'uris': <String>[
            'package:mcp_verify_project/mcp_verify_project.dart'
          ],
          'include_full_text': true,
        },
      );
      workspaceReport['package_uri_resource'] = await _readJsonResource(
        server,
        Uri(
          scheme: 'cockpit',
          host: 'package',
          path: '/read',
          queryParameters: <String, String>{
            'workspace_root': projectRoot,
            'uri': 'package:mcp_verify_project/mcp_verify_project.dart',
          },
        ).toString(),
      );
      workspaceReport['lsp_hover'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'hover',
          'path': 'bin/mcp_verify_project.dart',
          'line': 4,
          'column': 24,
          'timeout_seconds': 20,
        },
      );
      workspaceReport['lsp_definition'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'definition',
          'path': 'bin/mcp_verify_project.dart',
          'line': 4,
          'column': 24,
          'timeout_seconds': 20,
        },
      );
      workspaceReport['lsp_signature_help'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'signature_help',
          'path': 'bin/mcp_verify_project.dart',
          'line': 4,
          'column': 17,
          'timeout_seconds': 20,
        },
      );
      workspaceReport['lsp_document_symbols'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'document_symbols',
          'path': 'lib/mcp_verify_project.dart',
          'timeout_seconds': 20,
        },
      );
      workspaceReport['lsp_workspace_symbols'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'workspace_symbols',
          'query': 'describeValue',
          'timeout_seconds': 20,
        },
      );
      workspaceReport['analyze_files'] = await _callTool(
        server,
        'analyze_files',
        <String, Object?>{
          'workspace_root': projectRoot,
          'paths': <String>['lib/unused.dart'],
          'timeout_seconds': 120,
        },
      );
      workspaceReport['format_workspace'] = await _callTool(
        server,
        'format_workspace',
        <String, Object?>{
          'workspace_root': projectRoot,
          'timeout_seconds': 90,
        },
      );
      final formattedSource = File(
        p.join(projectRoot, 'lib', 'unformatted.dart'),
      ).readAsStringSync();
      workspaceReport['formatted_source'] = formattedSource;
      workspaceReport['apply_fixes'] = await _callTool(
        server,
        'apply_fixes',
        <String, Object?>{
          'workspace_root': projectRoot,
          'timeout_seconds': 180,
        },
      );
      workspaceReport['fixed_source'] = File(
        p.join(projectRoot, 'lib', 'fix_me.dart'),
      ).readAsStringSync();
      File(p.join(projectRoot, 'lib', 'unused.dart')).writeAsStringSync(
        'int cleanValue() => 1;\n',
      );
      workspaceReport['run_tests'] = await _callTool(
        server,
        'run_tests',
        <String, Object?>{
          'workspace_root': projectRoot,
          'timeout_seconds': 300,
        },
      );
      workspaceReport['analyze_workspace'] = await _callTool(
        server,
        'analyze_workspace',
        <String, Object?>{
          'workspace_root': projectRoot,
          'timeout_seconds': 180,
        },
      );
      workspaceReport['pub_remove'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspace_root': projectRoot,
          'command': 'remove',
          'packages': <String>['collection'],
          'timeout_seconds': 240,
        },
      );
      appReport['list_targets'] = await _callTool(
        server,
        'list_targets',
        const <String, Object?>{},
      );
      final launchPort = await _freePort();
      final launchResult = await _callTool(
        server,
        'launch_app',
        <String, Object?>{
          'project_dir': p.join(_repoRoot, 'examples', 'cockpit_demo'),
          'platform': 'macos',
          'device_id': 'macos',
          'session_port': launchPort,
          'launch_timeout_seconds': 150,
          'app_json': appJsonPath,
        },
      );
      appId =
          ((launchResult['app'] as Map<String, Object?>)['app_id'] as String?)!;
      appReport['launch_app'] = launchResult;
      appReport['list_apps'] = await _callTool(
        server,
        'list_apps',
        const <String, Object?>{},
      );
      appReport['apps_resource'] = await _readJsonResource(
        server,
        'cockpit://app/list',
      );
      appReport['app_resource'] = await _readJsonResource(
        server,
        'cockpit://app/details?app_id=$appId',
      );
      appReport['read_app'] = await _callTool(
        server,
        'read_app',
        <String, Object?>{
          'app_id': appId,
          'profile': 'minimal',
        },
      );
      final inboxInspection = await _callTool(
        server,
        'inspect_ui',
        <String, Object?>{
          'app_id': appId,
          'profile': 'standard',
        },
      );
      final inboxSnapshotRef = inboxInspection['snapshot_ref'] as String?;
      appReport['inspect_ui_inbox'] = inboxInspection;
      appReport['open_settings'] = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'app_id': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'command_id': 'open-settings',
            'command_type': 'tap',
            'locator': <String, Object?>{
              'key': 'open-settings-button',
              'tooltip': 'Settings',
              'route': '/inbox',
            },
          },
        },
      );
      appReport['inspect_ui_settings'] = await _callTool(
        server,
        'inspect_ui',
        <String, Object?>{
          'app_id': appId,
          'profile': 'inspect',
          if (inboxSnapshotRef != null)
            'compare_against_snapshot_ref': inboxSnapshotRef,
        },
      );
      final scrollSyncCheckResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'app_id': appId,
          'profile': 'inspect',
          'timeout_ms': 20000,
          'command': <String, Object?>{
            'command_id': 'scroll-sync-check',
            'command_type': 'scroll_until_visible',
            'locator': <String, Object?>{
              'key': 'settings-sync-check-button',
              'text': 'Run check',
              'route': '/settings',
              'ancestor': <String, Object?>{'route': '/settings'},
            },
            'parameters': <String, Object?>{
              'max_scrolls': 10,
              'viewport_fraction': 0.82,
              'continuous': true,
              'duration_per_step_ms': 220,
              'reveal_alignment': 'center',
              'scrollable_locator': <String, Object?>{
                'type': 'ListView',
                'path': 'scaffold.body/list_view.slivers/0',
                'route': '/settings',
              },
            },
          },
        },
      );
      appReport['scroll_sync_check'] = scrollSyncCheckResult;
      _requireCommandSuccess(
        'scroll_sync_check',
        scrollSyncCheckResult,
      );

      final tapSyncCheckResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'app_id': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'command_id': 'tap-sync-check',
            'command_type': 'tap',
            'locator': <String, Object?>{
              'key': 'settings-sync-check-button',
              'text': 'Run check',
              'route': '/settings',
            },
          },
        },
      );
      appReport['tap_sync_check'] = tapSyncCheckResult;
      _requireCommandSuccess('tap_sync_check', tapSyncCheckResult);

      final waitIdleAfterSyncCheck = await _callTool(
        server,
        'wait_idle',
        <String, Object?>{
          'app_id': appId,
          'timeout_ms': 5000,
          'quiet_window_ms': 160,
          'include_network_idle': true,
        },
      );
      appReport['wait_idle_after_sync_check'] = waitIdleAfterSyncCheck;
      _requireIdle('wait_idle_after_sync_check', waitIdleAfterSyncCheck);

      final readNetworkResult = await _callTool(
        server,
        'read_network',
        <String, Object?>{
          'app_id': appId,
          'uri_contains': '/sync/health',
          'include_entries': true,
        },
      );
      appReport['read_network'] = readNetworkResult;
      _requireNetworkEvidence(readNetworkResult, uriContains: '/sync/health');

      final scrollDebugLogResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'app_id': appId,
          'profile': 'inspect',
          'timeout_ms': 20000,
          'command': <String, Object?>{
            'command_id': 'scroll-debug-log',
            'command_type': 'scroll_until_visible',
            'locator': <String, Object?>{
              'key': 'settings-debug-log-button',
              'text': 'Emit debug log',
              'route': '/settings',
              'ancestor': <String, Object?>{'route': '/settings'},
            },
            'parameters': <String, Object?>{
              'max_scrolls': 10,
              'viewport_fraction': 0.82,
              'continuous': true,
              'duration_per_step_ms': 220,
              'reveal_alignment': 'center',
              'scrollable_locator': <String, Object?>{
                'type': 'ListView',
                'path': 'scaffold.body/list_view.slivers/0',
                'route': '/settings',
              },
            },
          },
        },
      );
      appReport['scroll_debug_log'] = scrollDebugLogResult;
      _requireCommandSuccess('scroll_debug_log', scrollDebugLogResult);

      final tapDebugLogResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'app_id': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'command_id': 'tap-debug-log',
            'command_type': 'tap',
            'locator': <String, Object?>{
              'key': 'settings-debug-log-button',
              'text': 'Emit debug log',
              'route': '/settings',
            },
          },
        },
      );
      appReport['tap_debug_log'] = tapDebugLogResult;
      _requireCommandSuccess('tap_debug_log', tapDebugLogResult);

      appReport['read_logs'] = await _callTool(
        server,
        'read_logs',
        <String, Object?>{
          'app_id': appId,
          'max_lines': 40,
        },
      );
      appReport['start_recording'] = await _callTool(
        server,
        'start_recording',
        <String, Object?>{
          'app_id': appId,
          'recording': <String, Object?>{
            'purpose': 'diagnostic',
            'name': 'mcp-runtime-error',
            'tail_stabilization_ms': 1000,
          },
        },
      );
      appReport['tap_runtime_error'] = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'app_id': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'command_id': 'tap-runtime-error',
            'command_type': 'tap',
            'locator': <String, Object?>{
              'key': 'settings-runtime-error-button',
              'text': 'Trigger runtime error',
              'route': '/settings',
            },
          },
        },
      );
      appReport['read_errors'] = await _callTool(
        server,
        'read_errors',
        <String, Object?>{
          'app_id': appId,
          'max_errors': 10,
        },
      );
      appReport['stop_recording'] = await _callTool(
        server,
        'stop_recording',
        <String, Object?>{
          'app_id': appId,
        },
      );
      appReport['run_batch'] = await _callTool(
        server,
        'run_batch',
        <String, Object?>{
          'app_id': appId,
          'commands': <Map<String, Object?>>[
            <String, Object?>{
              'command_id': 'back-to-inbox',
              'command_type': 'back',
            },
            <String, Object?>{
              'command_id': 'wait-after-back',
              'command_type': 'wait_for_ui_idle',
            },
            <String, Object?>{
              'command_id': 'assert-inbox',
              'command_type': 'assert_text',
              'parameters': <String, Object?>{'text': 'Inbox'},
            },
          ],
          'default_profile': 'minimal',
          'final_profile': 'standard',
          'default_timeout_ms': 6000,
          'fail_fast': true,
        },
      );
      appReport['wait_idle'] = await _callTool(
        server,
        'wait_idle',
        <String, Object?>{
          'app_id': appId,
          'timeout_ms': 2000,
        },
      );
      appReport['hot_reload'] = await _callTool(
        server,
        'hot_reload',
        <String, Object?>{'app_id': appId},
      );
      appReport['hot_restart'] = await _callTool(
        server,
        'hot_restart',
        <String, Object?>{'app_id': appId},
      );
      appReport['read_app_after_restart'] = await _callTool(
        server,
        'read_app',
        <String, Object?>{
          'app_id': appId,
          'profile': 'minimal',
        },
      );

      final runScriptOutput = p.join(verifyDirectory.path, 'run_script_out');
      final runScriptResult = await _callTool(
        server,
        'run_script',
        <String, Object?>{
          'app_id': appId,
          'output_root': runScriptOutput,
          'script': _scriptJson(
            sessionId: 'mcp-run-script-session',
            taskId: 'mcp-run-script-task',
            screenshotName: 'mcp-run-script',
          ),
        },
      );
      appReport['run_script'] = runScriptResult;
      appReport['read_task_bundle_summary'] = await _callTool(
        server,
        'read_task_bundle_summary',
        <String, Object?>{
          'bundle_dir': runScriptResult['bundle_dir'],
        },
      );

      final runTaskResult = await _callTool(
        server,
        'run_task',
        _runTaskJson(
          sessionPort: await _freePort(),
          outputRoot: p.join(verifyDirectory.path, 'run_task_out'),
          sessionId: 'mcp-run-task-session',
          taskId: 'mcp-run-task-task',
          screenshotName: 'mcp-run-task',
        ),
      );
      appReport['run_task'] = runTaskResult;
      appReport['latest_task_resource'] = await _readJsonResource(
        server,
        'cockpit://task/latest',
      );
      appReport['validate_task'] = await _callTool(
        server,
        'validate_task',
        _validateTaskJson(
          sessionPort: await _freePort(),
          outputRoot: p.join(verifyDirectory.path, 'validate_task_out'),
          sessionId: 'mcp-validate-task-session',
          taskId: 'mcp-validate-task-task',
          screenshotName: 'mcp-validate-task',
        ),
      );
    } finally {
      if (appId != null) {
        try {
          appReport['stop_app'] = await _callTool(
            server,
            'stop_app',
            <String, Object?>{'app_id': appId},
          );
          appReport['list_apps_after_stop'] = await _callTool(
            server,
            'list_apps',
            const <String, Object?>{},
          );
        } on Object {
          // Keep the report from the original failure.
        }
      }
    }

    return _VerificationReport(
      verifyRoot: verifyDirectory.path,
      summary: report,
    );
  }

  Future<Map<String, Object?>> _rpc(
    CockpitMcpServer server,
    String method, [
    Map<String, Object?>? params,
  ]) async {
    final response = await server.handleMessage(<String, Object?>{
      'jsonrpc': '2.0',
      'id': ++_requestId,
      'method': method,
      if (params != null) 'params': params,
    });
    if (response == null) {
      throw StateError('MCP server returned no response for $method.');
    }
    final error = response['error'] as Map<Object?, Object?>?;
    if (error != null) {
      throw StateError(
        'MCP $method failed: ${jsonEncode(Map<String, Object?>.from(error))}',
      );
    }
    final result = response['result'];
    if (result is! Map<Object?, Object?>) {
      throw StateError('MCP $method returned an unexpected result shape.');
    }
    return Map<String, Object?>.from(result);
  }

  Future<Map<String, Object?>> _callTool(
    CockpitMcpServer server,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final result = await _rpc(server, 'tools/call', <String, Object?>{
      'name': name,
      'arguments': arguments,
    });
    final structured = result['structuredContent'];
    if (structured is! Map<Object?, Object?>) {
      throw StateError('Tool $name did not return structuredContent.');
    }
    return Map<String, Object?>.from(structured);
  }

  Future<List<String>> _toolNames(CockpitMcpServer server) async {
    final result = await _rpc(server, 'tools/list');
    return ((result['tools'] as List<Object?>?) ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((tool) => '${tool['name']}')
        .toList(growable: false);
  }

  Future<List<String>> _resourceNames(CockpitMcpServer server) async {
    final result = await _rpc(server, 'resources/list');
    return ((result['resources'] as List<Object?>?) ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((resource) => '${resource['name']}')
        .toList(growable: false);
  }

  Future<List<String>> _resourceTemplateNames(CockpitMcpServer server) async {
    final result = await _rpc(server, 'resources/templates/list');
    return ((result['resourceTemplates'] as List<Object?>?) ??
            const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((resource) => '${resource['name']}')
        .toList(growable: false);
  }

  Future<List<String>> _promptNames(CockpitMcpServer server) async {
    final result = await _rpc(server, 'prompts/list');
    return ((result['prompts'] as List<Object?>?) ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((prompt) => '${prompt['name']}')
        .toList(growable: false);
  }

  Future<List<String>> _roots(CockpitMcpServer server) async {
    final result = await _rpc(server, 'roots/list');
    return ((result['roots'] as List<Object?>?) ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((root) => '${root['uri']}')
        .toList(growable: false);
  }

  Future<String> _readTextResource(CockpitMcpServer server, String uri) async {
    final result = await _rpc(server, 'resources/read', <String, Object?>{
      'uri': uri,
    });
    final contents = (result['contents'] as List<Object?>)
        .whereType<Map<Object?, Object?>>()
        .toList(growable: false);
    return '${contents.first['text'] ?? ''}';
  }

  Future<Map<String, Object?>> _readJsonResource(
    CockpitMcpServer server,
    String uri,
  ) async {
    final text = await _readTextResource(server, uri);
    return Map<String, Object?>.from(
      jsonDecode(text) as Map<Object?, Object?>,
    );
  }

  Future<List<Map<String, Object?>>> _getPrompt(
    CockpitMcpServer server,
    String name,
    Map<String, Object?> arguments,
  ) async {
    final result = await _rpc(server, 'prompts/get', <String, Object?>{
      'name': name,
      'arguments': arguments,
    });
    return ((result['messages'] as List<Object?>?) ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((message) => Map<String, Object?>.from(message))
        .toList(growable: false);
  }

  Future<void> _prepareWorkspaceProject(String projectRoot) async {
    File(p.join(projectRoot, 'lib', 'mcp_verify_project.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(r'''
int addOne(int value) => value + 1;
int add(int left, int right) => left + right;
String describeValue(int value) => 'value=$value';
''');
    File(p.join(projectRoot, 'bin', 'mcp_verify_project.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
import 'package:mcp_verify_project/mcp_verify_project.dart';

void main() {
  final total = add(1, addOne(40));
  print(describeValue(total));
}
''');
    File(p.join(projectRoot, 'lib', 'unused.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
import 'dart:math';

int unusedValue() => 1;
''');
    File(p.join(projectRoot, 'lib', 'fix_me.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
StringBuffer buildBuffer() {
  return new StringBuffer();
}
''');
    File(p.join(projectRoot, 'lib', 'unformatted.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('''
int   sum( int left,int right ){return left+right;}
''');
  }

  Future<int> _freePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  void _requireCommandSuccess(String label, Map<String, Object?> result) {
    final command = result['command'] as Map<Object?, Object?>?;
    final success = command?['success'] as bool?;
    if (success == true) {
      return;
    }
    throw StateError(
      '$label did not complete successfully: ${jsonEncode(result)}',
    );
  }

  void _requireIdle(String label, Map<String, Object?> result) {
    final idle = result['idle'] as bool?;
    if (idle == true) {
      return;
    }
    throw StateError('$label did not reach idle: ${jsonEncode(result)}');
  }

  void _requireNetworkEvidence(
    Map<String, Object?> result, {
    required String uriContains,
  }) {
    final summary = result['summary'] as Map<Object?, Object?>?;
    final totalEntryCount = summary?['total_entry_count'] as int? ?? 0;
    if (totalEntryCount <= 0) {
      throw StateError(
        'read_network did not capture any matching traffic for $uriContains: '
        '${jsonEncode(result)}',
      );
    }
    final endpointSummaries =
        (result['endpoint_summaries'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>();
    final matchedEndpoint = endpointSummaries.any((summary) {
      final uriPattern = '${summary['uri_pattern'] ?? ''}';
      final latestUri = '${summary['latest_uri'] ?? ''}';
      return uriPattern.contains(uriContains) ||
          latestUri.contains(uriContains);
    });
    if (!matchedEndpoint) {
      throw StateError(
        'read_network captured traffic but not the expected endpoint '
        '$uriContains: ${jsonEncode(result)}',
      );
    }
  }

  Map<String, Object?> _scriptJson({
    required String sessionId,
    required String taskId,
    required String screenshotName,
  }) {
    return <String, Object?>{
      'session_id': sessionId,
      'task_id': taskId,
      'platform': 'macos',
      'environment': <String, Object?>{
        'platform': 'macos',
        'flutter_version': '3.38.9',
        'dart_version': '3.10.8',
      },
      'recording': <String, Object?>{
        'purpose': 'acceptance',
        'name': screenshotName,
        'tail_stabilization_ms': 1400,
      },
      'commands': <Map<String, Object?>>[
        <String, Object?>{
          'command_id': 'open-today',
          'command_type': 'tap',
          'locator': <String, Object?>{
            'key': 'nav-today',
            'text': 'Today',
            'type': 'TextButton',
            'route': '/inbox',
          },
        },
        <String, Object?>{
          'command_id': 'wait-after-today',
          'command_type': 'wait_for_ui_idle',
        },
        <String, Object?>{
          'command_id': 'assert-today',
          'command_type': 'assert_text',
          'parameters': <String, Object?>{'text': 'Today'},
        },
        <String, Object?>{
          'command_id': 'capture-today',
          'command_type': 'capture_screenshot',
          'screenshot_request': <String, Object?>{
            'reason': 'acceptance',
            'name': screenshotName,
            'include_snapshot': true,
            'attach_to_step': true,
          },
        },
      ],
      'fail_fast': true,
    };
  }

  Map<String, Object?> _runTaskJson({
    required int sessionPort,
    required String outputRoot,
    required String sessionId,
    required String taskId,
    required String screenshotName,
  }) {
    return <String, Object?>{
      'launch': <String, Object?>{
        'project_dir': p.join(_repoRoot, 'examples', 'cockpit_demo'),
        'platform': 'macos',
        'device_id': 'macos',
        'session_port': sessionPort,
      },
      'script': _scriptJson(
        sessionId: sessionId,
        taskId: taskId,
        screenshotName: screenshotName,
      ),
      'output_root': outputRoot,
      'baseline': <String, Object?>{
        'capture_screenshot': true,
        'screenshot_name': 'baseline',
      },
      'requirements': <String, Object?>{
        'require_screenshot_evidence': true,
        'require_video_evidence': true,
      },
    };
  }

  Map<String, Object?> _validateTaskJson({
    required int sessionPort,
    required String outputRoot,
    required String sessionId,
    required String taskId,
    required String screenshotName,
  }) {
    return <String, Object?>{
      'run_task': _runTaskJson(
        sessionPort: sessionPort,
        outputRoot: outputRoot,
        sessionId: sessionId,
        taskId: taskId,
        screenshotName: screenshotName,
      ),
      'validation': <String, Object?>{
        'expected_classification': 'completed',
        'require_acceptance_markdown': true,
        'require_environment_snapshot': true,
        'require_primary_screenshot': true,
        'require_primary_recording': true,
        'require_artifact_files': true,
        'require_acceptance_semantic_evidence': true,
      },
    };
  }
}
