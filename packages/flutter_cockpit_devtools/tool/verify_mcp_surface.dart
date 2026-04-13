import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_cockpit_devtools/src/mcp/core/cockpit_mcp_stdio_channel.dart';
import 'package:flutter_cockpit_devtools/src/mcp/verification/cockpit_sync_lab_real_verification.dart';

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
    final mcpCliReport = <String, Object?>{};
    final workspaceReport = <String, Object?>{};
    final targetReport = <String, Object?>{};
    final appReport = <String, Object?>{};
    final syncLabReport = <String, Object?>{};
    report['mcp_cli_verification'] = mcpCliReport;
    report['workspace_verification'] = workspaceReport;
    report['target_verification'] = targetReport;
    report['app_verification'] = appReport;
    report['sync_lab_verification'] = syncLabReport;

    final server = CockpitMcpServer.standard(
      forceRootsFallback: true,
      workspaceRoots: <String>[_repoRoot, workspaceRoot.path],
    );

    final appJsonPath = p.join(verifyDirectory.path, 'example_app.json');
    final targetJsonPath = p.join(verifyDirectory.path, 'example_target.json');
    String? appId;
    String? targetAppId;

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
        'skill_contract': await _readTextResource(
          server,
          'cockpit://workspace/skill-contract',
        ),
        'task_bundle_contract': await _readTextResource(
          server,
          'cockpit://workspace/task-bundle-contract',
        ),
        'capabilities': await _readJsonResource(
          server,
          'cockpit://workspace/capabilities',
        ),
      };
      final promptPreview = await _getPrompt(
        server,
        'run_closed_loop_task',
        <String, Object?>{
          'taskGoal': 'Resolve sync conflicts with evidence.',
          'platform': 'macos',
          'requiresVideo': true,
        },
      );
      report['prompts_preview'] = promptPreview;
      final promptText = promptPreview.map((message) {
        final content = message['content'];
        if (content is Map<Object?, Object?>) {
          return '${content['text'] ?? ''}';
        }
        return '${message['text'] ?? ''}';
      }).join('\n');
      syncLabReport['promptHasHandleReuse'] = promptText.contains(
        'reuse the persisted app or target handle',
      );
      syncLabReport['promptHasBoundedSummaryGuidance'] = promptText.contains(
        'prefer bounded summary reads before full inspection',
      );
      syncLabReport['promptHasRouteAwareRecoveryGuidance'] = promptText
              .contains('do not blindly replay a non-idempotent batch') &&
          promptText.contains('re-read minimal route or state before retrying');
      syncLabReport['promptStatus'] =
          (syncLabReport['promptHasHandleReuse'] as bool) &&
                  (syncLabReport['promptHasBoundedSummaryGuidance'] as bool) &&
                  (syncLabReport['promptHasRouteAwareRecoveryGuidance'] as bool)
              ? 'passed'
              : 'failed';
      syncLabReport['status'] = 'pending';
      syncLabReport['artifactCleanup'] =
          await _cleanupCockpitDemoSyncLabArtifacts();
      report['mcp_cli_verification'] = await _verifyServeMcpCli(
        verifyDirectory.path,
      );

      final createdProject = await _callTool(
        server,
        'create_project',
        <String, Object?>{
          'parentDirectory': workspaceRoot.path,
          'projectName': 'mcp_verify_project',
          'template': 'dart_cli',
          'timeoutSeconds': 300,
        },
      );
      final projectRoot = createdProject['projectDirectory']! as String;
      report['workspace_project'] = <String, Object?>{
        'project_root': projectRoot,
      };
      await _prepareWorkspaceProject(projectRoot);

      workspaceReport['pub_dev_search'] = await _callTool(
        server,
        'pub_dev_search',
        <String, Object?>{
          'query': 'collection',
          'maxResults': 1,
          'timeoutSeconds': 20,
        },
      );
      workspaceReport['pub_get'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'get',
          'timeoutSeconds': 240,
        },
      );
      workspaceReport['pub_add'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'add',
          'packages': <String>['collection'],
          'timeoutSeconds': 240,
        },
      );
      workspaceReport['pub_deps'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'deps',
          'timeoutSeconds': 240,
        },
      );
      workspaceReport['pub_outdated'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'outdated',
          'timeoutSeconds': 240,
        },
      );
      workspaceReport['pub_upgrade'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'upgrade',
          'timeoutSeconds': 240,
        },
      );
      workspaceReport['package_uri_tool'] = await _callTool(
        server,
        'read_package_uris',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'uris': <String>[
            'package:mcp_verify_project/mcp_verify_project.dart'
          ],
          'includeFullText': true,
        },
      );
      workspaceReport['package_uri_resource'] = await _readJsonResource(
        server,
        Uri(
          scheme: 'cockpit',
          host: 'package',
          path: '/read',
          queryParameters: <String, String>{
            'workspaceRoot': projectRoot,
            'uri': 'package:mcp_verify_project/mcp_verify_project.dart',
          },
        ).toString(),
      );
      workspaceReport['grep_package_uris'] = await _callTool(
        server,
        'grep_package_uris',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'packageNames': <String>['mcp_verify_project'],
          'query': 'describeValue',
          'maxMatches': 5,
          'timeoutSeconds': 20,
        },
      );
      workspaceReport['lsp_hover'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'hover',
          'path': 'bin/mcp_verify_project.dart',
          'line': 4,
          'column': 24,
          'timeoutSeconds': 20,
        },
      );
      workspaceReport['lsp_definition'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'definition',
          'path': 'bin/mcp_verify_project.dart',
          'line': 4,
          'column': 24,
          'timeoutSeconds': 20,
        },
      );
      workspaceReport['lsp_signature_help'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'signature_help',
          'path': 'bin/mcp_verify_project.dart',
          'line': 4,
          'column': 17,
          'timeoutSeconds': 20,
        },
      );
      workspaceReport['lsp_document_symbols'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'document_symbols',
          'path': 'lib/mcp_verify_project.dart',
          'timeoutSeconds': 20,
        },
      );
      workspaceReport['lsp_workspace_symbols'] = await _callTool(
        server,
        'lsp',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'workspace_symbols',
          'query': 'describeValue',
          'timeoutSeconds': 20,
        },
      );
      workspaceReport['analyze_files'] = await _callTool(
        server,
        'analyze_files',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'paths': <String>['lib/unused.dart'],
          'timeoutSeconds': 120,
        },
      );
      workspaceReport['format_workspace'] = await _callTool(
        server,
        'format_workspace',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'timeoutSeconds': 90,
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
          'workspaceRoot': projectRoot,
          'timeoutSeconds': 180,
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
          'workspaceRoot': projectRoot,
          'timeoutSeconds': 300,
        },
      );
      workspaceReport['analyze_workspace'] = await _callTool(
        server,
        'analyze_workspace',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'timeoutSeconds': 180,
        },
      );
      workspaceReport['pub_remove'] = await _callTool(
        server,
        'pub',
        <String, Object?>{
          'workspaceRoot': projectRoot,
          'command': 'remove',
          'packages': <String>['collection'],
          'timeoutSeconds': 240,
        },
      );
      appReport['list_targets'] = await _callTool(
        server,
        'list_targets',
        const <String, Object?>{},
      );
      final targetLaunchResult = await _callTool(
        server,
        'launch_target',
        <String, Object?>{
          'projectDir': p.join(_repoRoot, 'examples', 'cockpit_demo'),
          'platform': 'macos',
          'deviceId': 'macos',
          'sessionPort': await _freePort(),
          'launchTimeoutSeconds': 150,
          'targetJson': targetJsonPath,
        },
      );
      targetReport['launch_target'] = targetLaunchResult;
      final launchedTarget =
          targetLaunchResult['target'] as Map<Object?, Object?>?;
      if ('${launchedTarget?['targetKind'] ?? ''}' != 'desktopApp') {
        throw StateError(
          'launch_target did not normalize the desktop target kind: '
          '${jsonEncode(targetLaunchResult)}',
        );
      }
      final persistedTargetJsonPath =
          '${targetLaunchResult['targetJsonPath'] ?? ''}';
      if (persistedTargetJsonPath.isEmpty ||
          p.normalize(persistedTargetJsonPath) != p.normalize(targetJsonPath)) {
        throw StateError(
          'launch_target did not persist targetJson to the requested path: '
          '${jsonEncode(targetLaunchResult)}',
        );
      }
      final targetApp = targetLaunchResult['app'] as Map<Object?, Object?>?;
      targetAppId = switch ('${targetApp?['appId'] ?? ''}') {
        '' => null,
        final value => value,
      };
      targetReport['read_target'] = await _callTool(
        server,
        'read_target',
        <String, Object?>{
          'targetJson': targetJsonPath,
          'profile': 'minimal',
        },
      );
      final targetRead = targetReport['read_target'] as Map<String, Object?>;
      if ('${targetRead['selectedPlane'] ?? ''}' != 'flutterSemanticPlane') {
        throw StateError(
          'read_target did not resolve the expected semantic plane: '
          '${jsonEncode(targetRead)}',
        );
      }
      targetReport['inspect_surface'] = await _callTool(
        server,
        'inspect_surface',
        <String, Object?>{
          'targetJson': targetJsonPath,
          'profile': 'inspect',
        },
      );
      final inspectSurface =
          targetReport['inspect_surface'] as Map<String, Object?>;
      if ('${inspectSurface['selectedPlane'] ?? ''}' !=
          'flutterSemanticPlane') {
        throw StateError(
          'inspect_surface did not resolve the expected semantic plane: '
          '${jsonEncode(inspectSurface)}',
        );
      }
      targetReport['run_shell_host'] = await _callTool(
        server,
        'run_shell',
        <String, Object?>{
          'scope': 'host',
          'command': <String>['echo', 'mcp-host-shell'],
        },
      );
      _requireShellSuccess(
        'run_shell_host',
        targetReport['run_shell_host'] as Map<String, Object?>,
        stdoutContains: 'mcp-host-shell',
      );
      targetReport['run_shell_target'] = await _callTool(
        server,
        'run_shell',
        <String, Object?>{
          'scope': 'target',
          'targetJson': targetJsonPath,
          'command': <String>['echo', 'mcp-target-shell'],
        },
      );
      _requireShellSuccess(
        'run_shell_target',
        targetReport['run_shell_target'] as Map<String, Object?>,
        stdoutContains: 'mcp-target-shell',
      );
      if (targetAppId != null) {
        targetReport['stop_target_app'] = await _callTool(
          server,
          'stop_app',
          <String, Object?>{'appId': targetAppId},
        );
        targetAppId = null;
      }
      final launchPort = await _freePort();
      final launchResult = await _callTool(
        server,
        'launch_app',
        <String, Object?>{
          'projectDir': p.join(_repoRoot, 'examples', 'cockpit_demo'),
          'platform': 'macos',
          'deviceId': 'macos',
          'sessionPort': launchPort,
          'launchTimeoutSeconds': 150,
          'appJson': appJsonPath,
        },
      );
      appId =
          ((launchResult['app'] as Map<String, Object?>)['appId'] as String?)!;
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
        'cockpit://app/details?appId=$appId',
      );
      appReport['read_app'] = await _callTool(
        server,
        'read_app',
        <String, Object?>{
          'appId': appId,
          'profile': 'minimal',
        },
      );
      final inboxInspection = await _callTool(
        server,
        'inspect_ui',
        <String, Object?>{
          'appId': appId,
          'profile': 'standard',
        },
      );
      final inboxSnapshotRef = inboxInspection['snapshotRef'] as String?;
      appReport['inspect_ui_inbox'] = inboxInspection;
      appReport['open_settings'] = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'commandId': 'open-settings',
            'commandType': 'tap',
            'locator': <String, Object?>{
              'tooltip': 'Settings',
              'route': '/inbox',
            },
          },
        },
      );
      _requireCommandSuccess(
        'open_settings',
        appReport['open_settings'] as Map<String, Object?>,
      );
      appReport['inspect_ui_settings'] = await _callTool(
        server,
        'inspect_ui',
        <String, Object?>{
          'appId': appId,
          'profile': 'inspect',
          if (inboxSnapshotRef != null)
            'compareAgainstSnapshotRef': inboxSnapshotRef,
        },
      );
      final settingsInspection =
          appReport['inspect_ui_settings'] as Map<String, Object?>;
      if ('${settingsInspection['routeName'] ?? ''}' != '/settings') {
        throw StateError(
          'inspect_ui_settings did not land on the settings route: '
          '${jsonEncode(settingsInspection)}',
        );
      }
      final scrollSyncCheckResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': 'inspect',
          'timeoutMs': 20000,
          'command': <String, Object?>{
            'commandId': 'scroll-sync-check',
            'commandType': 'scrollUntilVisible',
            'locator': <String, Object?>{
              'text': 'Run check',
              'route': '/settings',
              'ancestor': <String, Object?>{'route': '/settings'},
            },
            'parameters': <String, Object?>{
              'maxScrolls': 10,
              'viewportFraction': 0.82,
              'continuous': true,
              'durationPerStepMs': 220,
              'revealAlignment': 'center',
              'scrollableLocator': <String, Object?>{
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
          'appId': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'commandId': 'tap-sync-check',
            'commandType': 'tap',
            'locator': <String, Object?>{
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
          'appId': appId,
          'timeoutMs': 5000,
          'quietWindowMs': 160,
          'includeNetworkIdle': true,
        },
      );
      appReport['wait_idle_after_sync_check'] = waitIdleAfterSyncCheck;
      _requireIdle('wait_idle_after_sync_check', waitIdleAfterSyncCheck);

      final readNetworkResult = await _callTool(
        server,
        'read_network',
        <String, Object?>{
          'appId': appId,
          'uriContains': '/sync/health',
          'includeEntries': true,
        },
      );
      appReport['read_network'] = readNetworkResult;
      _requireNetworkEvidence(readNetworkResult, uriContains: '/sync/health');

      final scrollDebugLogResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': 'inspect',
          'timeoutMs': 20000,
          'command': <String, Object?>{
            'commandId': 'scroll-debug-log',
            'commandType': 'scrollUntilVisible',
            'locator': <String, Object?>{
              'text': 'Emit debug log',
              'route': '/settings',
              'ancestor': <String, Object?>{'route': '/settings'},
            },
            'parameters': <String, Object?>{
              'maxScrolls': 10,
              'viewportFraction': 0.82,
              'continuous': true,
              'durationPerStepMs': 220,
              'revealAlignment': 'center',
              'scrollableLocator': <String, Object?>{
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
          'appId': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'commandId': 'tap-debug-log',
            'commandType': 'tap',
            'locator': <String, Object?>{
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
          'appId': appId,
          'maxLines': 40,
        },
      );
      appReport['start_recording'] = await _callTool(
        server,
        'start_recording',
        <String, Object?>{
          'appId': appId,
          'recording': <String, Object?>{
            'purpose': 'diagnostic',
            'name': 'mcp-runtime-error',
            'tailStabilizationMs': 1000,
          },
        },
      );
      appReport['tap_runtime_error'] = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'commandId': 'tap-runtime-error',
            'commandType': 'tap',
            'locator': <String, Object?>{
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
          'appId': appId,
          'maxErrors': 10,
        },
      );
      appReport['stop_recording'] = await _callTool(
        server,
        'stop_recording',
        <String, Object?>{
          'appId': appId,
        },
      );
      appReport['run_batch'] = await _callTool(
        server,
        'run_batch',
        <String, Object?>{
          'appId': appId,
          'commands': <Map<String, Object?>>[
            <String, Object?>{
              'commandId': 'back-to-inbox',
              'commandType': 'back',
            },
            <String, Object?>{
              'commandId': 'wait-after-back',
              'commandType': 'waitForUiIdle',
            },
            <String, Object?>{
              'commandId': 'assert-inbox',
              'commandType': 'assertText',
              'parameters': <String, Object?>{'text': 'Inbox'},
            },
          ],
          'defaultProfile': 'minimal',
          'finalProfile': 'standard',
          'defaultTimeoutMs': 6000,
          'failFast': true,
        },
      );
      appReport['wait_idle'] = await _callTool(
        server,
        'wait_idle',
        <String, Object?>{
          'appId': appId,
          'timeoutMs': 2000,
        },
      );
      appReport['hot_reload'] = await _callTool(
        server,
        'hot_reload',
        <String, Object?>{'appId': appId},
      );
      appReport['hot_restart'] = await _callTool(
        server,
        'hot_restart',
        <String, Object?>{'appId': appId},
      );
      appReport['read_app_after_restart'] = await _callTool(
        server,
        'read_app',
        <String, Object?>{
          'appId': appId,
          'profile': 'minimal',
        },
      );
      appReport['wait_idle_after_restart'] = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': 'minimal',
          'command': <String, Object?>{
            'commandId': 'wait-after-hot-restart',
            'commandType': 'waitForUiIdle',
          },
        },
        remoteRetryAttempts: 6,
      );
      _requireCommandSuccess(
        'wait_idle_after_restart',
        appReport['wait_idle_after_restart'] as Map<String, Object?>,
      );

      try {
        final syncLabTaskTitle =
            'MCP sync conflict ${DateTime.now().toUtc().microsecondsSinceEpoch}';
        syncLabReport['taskTitle'] = syncLabTaskTitle;
        syncLabReport['createTaskBatch'] = await _callTool(
          server,
          'run_batch',
          <String, Object?>{
            'appId': appId,
            'commands':
                buildSyncLabCreateTaskBatch(taskTitle: syncLabTaskTitle),
            'defaultProfile': 'minimal',
            'finalProfile': 'standard',
            'defaultTimeoutMs': 30000,
            'failFast': true,
          },
          remoteRetryAttempts: 4,
        );
        _requireBatchSuccess(
          'sync_lab_create_task',
          syncLabReport['createTaskBatch'] as Map<String, Object?>,
          expectedCount: 5,
        );
        syncLabReport['postCreateRead'] = await _callTool(
          server,
          'read_app',
          <String, Object?>{
            'appId': appId,
            'profile': 'minimal',
          },
        );
        _requireCurrentRoute(
          'sync_lab_post_create_route',
          syncLabReport['postCreateRead'] as Map<String, Object?>,
          expectedRoute: '/inbox',
        );
        syncLabReport['conflictSyncBatch'] =
            await _runSyncLabConflictSyncSequence(
          server,
          appId: appId,
        );
        _requireBatchSuccess(
          'sync_lab_conflict_sync_batch',
          syncLabReport['conflictSyncBatch'] as Map<String, Object?>,
          expectedCount: 5,
        );
        syncLabReport['postConflictSyncIdle'] = await _callTool(
          server,
          'wait_idle',
          <String, Object?>{
            'appId': appId,
            'timeoutMs': 5000,
            'quietWindowMs': 180,
          },
          remoteRetryAttempts: 3,
        );
        _requireIdle(
          'sync_lab_post_conflict_sync_idle',
          syncLabReport['postConflictSyncIdle'] as Map<String, Object?>,
        );
        syncLabReport['conflictOpenSequence'] = await _runCommandSequence(
          server,
          appId: appId,
          commands: buildSyncLabOpenConflictBatch(taskTitle: syncLabTaskTitle),
          profile: 'minimal',
          timeoutMs: 30000,
          remoteRetryAttempts: 3,
        );
        syncLabReport['postConflictOpenIdle'] = await _callTool(
          server,
          'wait_idle',
          <String, Object?>{
            'appId': appId,
            'timeoutMs': 5000,
            'quietWindowMs': 180,
          },
          remoteRetryAttempts: 3,
        );
        _requireIdle(
          'sync_lab_post_conflict_open_idle',
          syncLabReport['postConflictOpenIdle'] as Map<String, Object?>,
        );
        syncLabReport['postConflictOpenRead'] = await _callTool(
          server,
          'read_app',
          <String, Object?>{
            'appId': appId,
            'profile': 'minimal',
          },
        );
        _requireCurrentRoute(
          'sync_lab_post_conflict_open_route',
          syncLabReport['postConflictOpenRead'] as Map<String, Object?>,
          expectedRoute: '/detail',
        );
        syncLabReport['openConflictResolution'] = await _callTool(
          server,
          'run_command',
          <String, Object?>{
            'appId': appId,
            'profile': 'minimal',
            'timeoutMs': 30000,
            'command': buildSyncLabOpenConflictResolutionCommand(),
          },
          remoteRetryAttempts: 3,
        );
        _requireCommandSuccess(
          'sync_lab_open_conflict_resolution',
          syncLabReport['openConflictResolution'] as Map<String, Object?>,
        );
        syncLabReport['postConflictRead'] = await _callTool(
          server,
          'read_app',
          <String, Object?>{
            'appId': appId,
            'profile': 'minimal',
          },
        );
        _requireCurrentRoute(
          'sync_lab_post_conflict_route',
          syncLabReport['postConflictRead'] as Map<String, Object?>,
          expectedRoute: '/sync-conflict',
        );
        syncLabReport['conflictInspect'] = await _callTool(
          server,
          'inspect_ui',
          <String, Object?>{
            'appId': appId,
            'profile': 'standard',
          },
        );
        if ('${(syncLabReport['conflictInspect'] as Map<String, Object?>)['routeName'] ?? ''}' !=
            '/sync-conflict') {
          throw StateError(
            'sync_lab conflict inspection did not land on /sync-conflict: '
            '${jsonEncode(syncLabReport['conflictInspect'])}',
          );
        }
        syncLabReport['keepLocalResolution'] = await _callTool(
          server,
          'run_command',
          <String, Object?>{
            'appId': appId,
            'profile': 'minimal',
            'command': buildSyncLabKeepLocalResolutionCommand(),
          },
          remoteRetryAttempts: 3,
        );
        _requireCommandSuccess(
          'sync_lab_keep_local_resolution',
          syncLabReport['keepLocalResolution'] as Map<String, Object?>,
        );
        syncLabReport['postResolutionRead'] = await _callTool(
          server,
          'read_app',
          <String, Object?>{
            'appId': appId,
            'profile': 'minimal',
          },
        );
        _requireCurrentRoute(
          'sync_lab_post_resolution_route',
          syncLabReport['postResolutionRead'] as Map<String, Object?>,
          expectedRoute: '/detail',
        );
        syncLabReport['recoverySyncBatch'] =
            await _runSyncLabRecoverySyncSequence(
          server,
          appId: appId,
        );
        _requireBatchSuccess(
          'sync_lab_recovery_sync_batch',
          syncLabReport['recoverySyncBatch'] as Map<String, Object?>,
          expectedCount: 6,
        );
        syncLabReport['postRecoverySyncIdle'] = await _callTool(
          server,
          'wait_idle',
          <String, Object?>{
            'appId': appId,
            'timeoutMs': 5000,
            'quietWindowMs': 180,
          },
          remoteRetryAttempts: 3,
        );
        _requireIdle(
          'sync_lab_post_recovery_sync_idle',
          syncLabReport['postRecoverySyncIdle'] as Map<String, Object?>,
        );
        syncLabReport['recoveryVerificationSequence'] =
            await _runCommandSequence(
          server,
          appId: appId,
          commands: buildSyncLabRecoveryVerificationBatch(
            taskTitle: syncLabTaskTitle,
          ),
          profile: 'minimal',
          timeoutMs: 30000,
          remoteRetryAttempts: 3,
        );
        syncLabReport['postRecoveryRead'] = await _callTool(
          server,
          'read_app',
          <String, Object?>{
            'appId': appId,
            'profile': 'minimal',
          },
        );
        _requireCurrentRoute(
          'sync_lab_post_recovery_route',
          syncLabReport['postRecoveryRead'] as Map<String, Object?>,
          expectedRoute: '/detail',
        );
        syncLabReport['postRecoveryInspect'] = await _callTool(
          server,
          'inspect_ui',
          <String, Object?>{
            'appId': appId,
            'profile': 'standard',
          },
        );
        syncLabReport['realFlowStatus'] = 'passed';
        syncLabReport['status'] = (syncLabReport['promptStatus'] == 'passed' &&
                syncLabReport['realFlowStatus'] == 'passed')
            ? 'passed'
            : 'failed';
      } on StateError catch (error) {
        syncLabReport['realFlowStatus'] = 'blocked';
        syncLabReport['status'] = 'blocked';
        syncLabReport['failureMessage'] = error.toString();
      }

      final runScriptOutput = p.join(verifyDirectory.path, 'run_script_out');
      try {
        appReport['pre_run_script_route'] = await _ensureRoute(
          server,
          appId: appId,
          expectedRoute: '/inbox',
          reportKeyPrefix: 'run_script',
        );
        final runScriptResult = await _callTool(
          server,
          'run_script',
          <String, Object?>{
            'appId': appId,
            'outputRoot': runScriptOutput,
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
            'bundleDir': runScriptResult['bundleDir'],
          },
        );
      } on StateError catch (error) {
        appReport['run_script_error'] = error.toString();
      }

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
      appReport['runTask'] = runTaskResult;
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
      if (targetAppId != null) {
        try {
          targetReport['stop_target_app'] = await _callTool(
            server,
            'stop_app',
            <String, Object?>{'appId': targetAppId},
          );
        } on Object {
          // Keep the report from the original failure.
        }
      }
      if (appId != null) {
        try {
          appReport['stop_app'] = await _callTool(
            server,
            'stop_app',
            <String, Object?>{'appId': appId},
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
      try {
        syncLabReport['postRunArtifactCleanup'] =
            await _cleanupCockpitDemoSyncLabArtifacts();
      } on Object catch (error) {
        syncLabReport['postRunArtifactCleanupError'] = error.toString();
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
    Map<String, Object?> arguments, {
    int remoteRetryAttempts = 1,
  }) async {
    for (var attempt = 0; attempt < remoteRetryAttempts; attempt += 1) {
      try {
        final result = await _rpc(server, 'tools/call', <String, Object?>{
          'name': name,
          'arguments': arguments,
        });
        final structured = result['structuredContent'];
        if (structured is! Map<Object?, Object?>) {
          throw StateError('Tool $name did not return structuredContent.');
        }
        return Map<String, Object?>.from(structured);
      } on StateError catch (error) {
        final retryable =
            error.toString().contains('"serviceCode":"remoteUnavailable"');
        final canRetry = retryable && attempt + 1 < remoteRetryAttempts;
        if (!canRetry) {
          rethrow;
        }
        await Future<void>.delayed(
          Duration(milliseconds: 600 * (attempt + 1)),
        );
      }
    }
    throw StateError('Tool $name exhausted remote retry attempts.');
  }

  Future<Map<String, Object?>> _cleanupCockpitDemoSyncLabArtifacts() async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      return <String, Object?>{
        'status': 'skipped',
        'reason': 'HOME environment variable is unavailable.',
      };
    }

    final databasePath = p.join(
      home,
      'Library',
      'Containers',
      'dev.cockpit.cockpitDemo',
      'Data',
      'Documents',
      'cockpit_demo.sqlite',
    );
    final databaseFile = File(databasePath);
    if (!databaseFile.existsSync()) {
      return <String, Object?>{
        'status': 'skipped',
        'databasePath': databasePath,
        'reason': 'cockpit_demo sqlite database does not exist yet.',
      };
    }

    final countResult = await Process.run(
      'sqlite3',
      <String>[
        databasePath,
        buildSyncLabVerifierArtifactCountSql(),
      ],
    );
    if (countResult.exitCode != 0) {
      throw StateError(
        'Failed to inspect sync lab verifier artifacts: '
        '${countResult.stderr}',
      );
    }

    final existingCount = int.tryParse('${countResult.stdout}'.trim()) ?? 0;
    if (existingCount == 0) {
      return <String, Object?>{
        'status': 'clean',
        'databasePath': databasePath,
        'removedTaskCount': 0,
      };
    }

    final deleteResult = await Process.run(
      'sqlite3',
      <String>[
        databasePath,
        buildSyncLabVerifierArtifactCleanupSql(),
      ],
    );
    if (deleteResult.exitCode != 0) {
      throw StateError(
        'Failed to remove sync lab verifier artifacts: ${deleteResult.stderr}',
      );
    }

    return <String, Object?>{
      'status': 'cleaned',
      'databasePath': databasePath,
      'removedTaskCount': existingCount,
    };
  }

  Future<Map<String, Object?>> _ensureRoute(
    CockpitMcpServer server, {
    required String appId,
    required String expectedRoute,
    required String reportKeyPrefix,
  }) async {
    var routeState = await _callTool(
      server,
      'read_app',
      <String, Object?>{
        'appId': appId,
        'profile': 'minimal',
      },
    );
    var currentRoute = '${routeState['currentRouteName'] ?? ''}';
    final steps = <Map<String, Object?>>[];
    for (var attempt = 0;
        currentRoute.isNotEmpty && currentRoute != expectedRoute && attempt < 4;
        attempt += 1) {
      final backResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': 'minimal',
          'timeoutMs': 15000,
          'command': <String, Object?>{
            'commandId': '$reportKeyPrefix-return-to-inbox-$attempt',
            'commandType': 'tap',
            'locator': <String, Object?>{
              'tooltip': 'Back',
              'ancestor': <String, Object?>{'route': currentRoute},
            },
          },
        },
        remoteRetryAttempts: 3,
      );
      _requireCommandSuccess(
        '$reportKeyPrefix-return-to-inbox-$attempt',
        backResult,
      );
      steps.add(backResult);
      routeState = await _callTool(
        server,
        'read_app',
        <String, Object?>{
          'appId': appId,
          'profile': 'minimal',
        },
      );
      currentRoute = '${routeState['currentRouteName'] ?? ''}';
    }
    if (currentRoute != expectedRoute) {
      throw StateError(
        '$reportKeyPrefix could not return the app to $expectedRoute from '
        '$currentRoute: ${jsonEncode(routeState)}',
      );
    }
    return <String, Object?>{
      'route': currentRoute,
      'steps': steps,
      'state': routeState,
    };
  }

  Future<List<Map<String, Object?>>> _runCommandSequence(
    CockpitMcpServer server, {
    required String appId,
    required List<Map<String, Object?>> commands,
    required String profile,
    required int timeoutMs,
    int remoteRetryAttempts = 1,
  }) async {
    final results = <Map<String, Object?>>[];
    for (final command in commands) {
      final commandId = '${command['commandId'] ?? 'unknown-command'}';
      late final Map<String, Object?> result;
      try {
        result = await _callTool(
          server,
          'run_command',
          <String, Object?>{
            'appId': appId,
            'profile': profile,
            'timeoutMs': timeoutMs,
            'command': command,
          },
          remoteRetryAttempts: remoteRetryAttempts,
        );
      } on StateError catch (error) {
        throw StateError(
          'Command sequence failed at $commandId: ${error.toString()}',
        );
      }
      _requireCommandSuccess(commandId, result);
      results.add(result);
    }
    return results;
  }

  Future<Map<String, Object?>> _runSyncLabConflictSyncSequence(
    CockpitMcpServer server, {
    required String appId,
  }) async {
    final commands = buildSyncLabConflictSyncBatch();
    final results = <Map<String, Object?>>[
      await _runCommandWithRouteFallback(
        server,
        appId: appId,
        command: commands[0],
        profile: 'minimal',
        timeoutMs: 30000,
        successRoute: '/settings',
      ),
      ...await _runCommandSequence(
        server,
        appId: appId,
        commands: <Map<String, Object?>>[commands[1]],
        profile: 'minimal',
        timeoutMs: 30000,
        remoteRetryAttempts: 3,
      ),
      ...await _runCommandWithDeferredWaitVerification(
        server,
        appId: appId,
        command: commands[2],
        waitCommand: commands[3],
        profile: 'minimal',
        timeoutMs: 30000,
      ),
      await _runCommandWithRouteFallback(
        server,
        appId: appId,
        command: commands[4],
        profile: 'minimal',
        timeoutMs: 30000,
        successRoute: '/inbox',
      ),
    ];
    return _commandSequenceReport(results);
  }

  Future<Map<String, Object?>> _runSyncLabRecoverySyncSequence(
    CockpitMcpServer server, {
    required String appId,
  }) async {
    final commands = buildSyncLabRecoverySyncBatch();
    final results = <Map<String, Object?>>[
      await _runCommandWithRouteFallback(
        server,
        appId: appId,
        command: commands[0],
        profile: 'minimal',
        timeoutMs: 30000,
        successRoute: '/inbox',
      ),
      await _runCommandWithRouteFallback(
        server,
        appId: appId,
        command: commands[1],
        profile: 'minimal',
        timeoutMs: 30000,
        successRoute: '/settings',
      ),
      ...await _runCommandSequence(
        server,
        appId: appId,
        commands: <Map<String, Object?>>[commands[2]],
        profile: 'minimal',
        timeoutMs: 30000,
        remoteRetryAttempts: 3,
      ),
      ...await _runCommandWithDeferredWaitVerification(
        server,
        appId: appId,
        command: commands[3],
        waitCommand: commands[4],
        profile: 'minimal',
        timeoutMs: 30000,
      ),
      await _runCommandWithRouteFallback(
        server,
        appId: appId,
        command: commands[5],
        profile: 'minimal',
        timeoutMs: 30000,
        successRoute: '/inbox',
      ),
    ];
    return _commandSequenceReport(results);
  }

  Future<Map<String, Object?>> _runCommandWithRouteFallback(
    CockpitMcpServer server, {
    required String appId,
    required Map<String, Object?> command,
    required String profile,
    required int timeoutMs,
    required String successRoute,
  }) async {
    final commandId = '${command['commandId'] ?? 'unknown-command'}';
    try {
      final result = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': profile,
          'timeoutMs': timeoutMs,
          'command': command,
        },
      );
      if (_commandSucceeded(result)) {
        return result;
      }
      final currentRoute = await _readCurrentRoute(server, appId: appId);
      if (_canTreatRouteAsRecovered(result, currentRoute: currentRoute) &&
          currentRoute == successRoute) {
        return _syntheticRecoveredCommandResult(
          command,
          currentRoute: currentRoute,
          recoveryReason: 'route-already-reached',
          originalResult: result,
        );
      }
      _requireCommandSuccess(commandId, result);
    } on StateError catch (error) {
      if (!_isRemoteUnavailableError(error)) {
        rethrow;
      }
      final currentRoute = await _readCurrentRoute(server, appId: appId);
      if (currentRoute == successRoute) {
        return _syntheticRecoveredCommandResult(
          command,
          currentRoute: currentRoute,
          recoveryReason: 'remote-unavailable-after-success',
          originalError: error.toString(),
        );
      }
      final retryResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': profile,
          'timeoutMs': timeoutMs,
          'command': command,
        },
      );
      if (_commandSucceeded(retryResult)) {
        return retryResult;
      }
      final retryRoute = await _readCurrentRoute(server, appId: appId);
      if (_canTreatRouteAsRecovered(retryResult, currentRoute: retryRoute) &&
          retryRoute == successRoute) {
        return _syntheticRecoveredCommandResult(
          command,
          currentRoute: retryRoute,
          recoveryReason: 'route-reached-after-single-retry',
          originalResult: retryResult,
          originalError: error.toString(),
        );
      }
      _requireCommandSuccess(commandId, retryResult);
    }
    throw StateError('Command $commandId did not reach the expected route.');
  }

  Future<List<Map<String, Object?>>> _runCommandWithDeferredWaitVerification(
    CockpitMcpServer server, {
    required String appId,
    required Map<String, Object?> command,
    required Map<String, Object?> waitCommand,
    required String profile,
    required int timeoutMs,
  }) async {
    Map<String, Object?>? commandResult;
    Object? commandError;
    try {
      commandResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': profile,
          'timeoutMs': timeoutMs,
          'command': command,
        },
      );
      if (!_commandSucceeded(commandResult)) {
        commandError = StateError(jsonEncode(commandResult));
      }
    } on StateError catch (error) {
      commandError = error;
    }

    late final Map<String, Object?> waitResult;
    try {
      waitResult = await _callTool(
        server,
        'run_command',
        <String, Object?>{
          'appId': appId,
          'profile': profile,
          'timeoutMs': timeoutMs,
          'command': waitCommand,
        },
        remoteRetryAttempts: 3,
      );
      _requireCommandSuccess(
        '${waitCommand['commandId'] ?? 'unknown-wait-command'}',
        waitResult,
      );
    } on StateError catch (error) {
      if (commandError != null) {
        throw StateError(
          'Deferred verification for ${command['commandId']} failed after '
          'action error $commandError and wait error ${error.toString()}',
        );
      }
      rethrow;
    }

    final normalizedCommandResult =
        commandResult != null && _commandSucceeded(commandResult)
            ? commandResult
            : _syntheticRecoveredCommandResult(
                command,
                currentRoute: await _readCurrentRoute(server, appId: appId),
                recoveryReason:
                    'validated-by-${waitCommand['commandId'] ?? 'wait-command'}',
                originalResult: commandResult,
                originalError: commandError?.toString(),
              );
    return <Map<String, Object?>>[
      normalizedCommandResult,
      waitResult,
    ];
  }

  Future<String> _readCurrentRoute(
    CockpitMcpServer server, {
    required String appId,
  }) async {
    final readResult = await _callTool(
      server,
      'read_app',
      <String, Object?>{
        'appId': appId,
        'profile': 'minimal',
      },
      remoteRetryAttempts: 3,
    );
    return '${readResult['currentRouteName'] ?? ''}';
  }

  Map<String, Object?> _commandSequenceReport(
    List<Map<String, Object?>> results,
  ) {
    final successCount = results.where(_commandSucceeded).length;
    final failureCount = results.length - successCount;
    return <String, Object?>{
      'results': results,
      'summary': <String, Object?>{
        'totalCount': results.length,
        'successCount': successCount,
        'failureCount': failureCount,
        'stoppedEarly': failureCount > 0,
      },
    };
  }

  bool _commandSucceeded(Map<String, Object?> result) {
    final command = result['command'] as Map<Object?, Object?>?;
    return command?['success'] == true;
  }

  bool _canTreatRouteAsRecovered(
    Map<String, Object?> result, {
    required String currentRoute,
  }) {
    final command = result['command'] as Map<Object?, Object?>?;
    final error = command?['error'] as Map<Object?, Object?>?;
    final errorCode = '${error?['code'] ?? ''}';
    return currentRoute.isNotEmpty && errorCode == 'targetNotFound';
  }

  bool _isRemoteUnavailableError(StateError error) {
    return error.toString().contains('"serviceCode":"remoteUnavailable"');
  }

  Map<String, Object?> _syntheticRecoveredCommandResult(
    Map<String, Object?> command, {
    required String currentRoute,
    required String recoveryReason,
    Map<String, Object?>? originalResult,
    String? originalError,
  }) {
    return <String, Object?>{
      'command': <String, Object?>{
        'commandId': command['commandId'],
        'commandType': command['commandType'],
        'success': true,
        'durationMs': 0,
        'usedCaptureFallback': false,
      },
      'recovery': <String, Object?>{
        'reason': recoveryReason,
        'currentRoute': currentRoute,
        if (originalError != null) 'originalError': originalError,
        if (originalResult != null) 'originalResult': originalResult,
      },
    };
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

  void _requireBatchSuccess(
    String label,
    Map<String, Object?> result, {
    required int expectedCount,
  }) {
    final summary = result['summary'] as Map<Object?, Object?>?;
    final totalCount = summary?['totalCount'] as int? ?? 0;
    final successCount = summary?['successCount'] as int? ?? 0;
    final failureCount = summary?['failureCount'] as int? ?? 0;
    final stoppedEarly = summary?['stoppedEarly'] as bool? ?? false;
    if (totalCount == expectedCount &&
        successCount == expectedCount &&
        failureCount == 0 &&
        !stoppedEarly) {
      return;
    }
    throw StateError(
        '$label did not complete successfully: ${jsonEncode(result)}');
  }

  void _requireCurrentRoute(
    String label,
    Map<String, Object?> result, {
    required String expectedRoute,
  }) {
    final currentRoute = '${result['currentRouteName'] ?? ''}';
    if (currentRoute == expectedRoute) {
      return;
    }
    throw StateError(
      '$label did not resolve the expected route $expectedRoute: '
      '${jsonEncode(result)}',
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
    final totalEntryCount = summary?['totalEntryCount'] as int? ?? 0;
    if (totalEntryCount <= 0) {
      throw StateError(
        'read_network did not capture any matching traffic for $uriContains: '
        '${jsonEncode(result)}',
      );
    }
    final endpointSummaries =
        (result['endpointSummaries'] as List<Object?>? ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>();
    final matchedEndpoint = endpointSummaries.any((summary) {
      final uriPattern = '${summary['uriPattern'] ?? ''}';
      final latestUri = '${summary['latestUri'] ?? ''}';
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

  void _requireShellSuccess(
    String label,
    Map<String, Object?> result, {
    String? stdoutContains,
  }) {
    final success = result['success'] as bool?;
    final stdout = '${result['stdout'] ?? ''}';
    if (success == true &&
        (stdoutContains == null || stdout.contains(stdoutContains))) {
      return;
    }
    throw StateError(
        '$label did not complete successfully: ${jsonEncode(result)}');
  }

  Future<Map<String, Object?>> _verifyServeMcpCli(String verifyRoot) async {
    final logPath = p.join(verifyRoot, 'serve_mcp_protocol.log');
    final process = await Process.start(
      'dart',
      <String>[
        'run',
        'flutter_cockpit_devtools:flutter_cockpit_devtools',
        'serve-mcp',
        '--workspace-root',
        _repoRoot,
        '--log-file',
        logPath,
      ],
      workingDirectory: _repoRoot,
    );
    final stderrBuffer = StringBuffer();
    final stderrSubscription =
        process.stderr.transform(utf8.decoder).listen(stderrBuffer.write);
    final channel = cockpitMcpStdioChannel(
      input: process.stdout,
      output: process.stdin,
    );
    final responses = StreamIterator<String>(channel.stream);
    var requestId = 0;

    Future<Map<String, Object?>> rpc(
      String method, [
      Map<String, Object?>? params,
    ]) async {
      final id = ++requestId;
      channel.sink.add(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'method': method,
          if (params != null) 'params': params,
        }),
      );
      while (await responses.moveNext()) {
        final payload = Map<String, Object?>.from(
          jsonDecode(responses.current) as Map<Object?, Object?>,
        );
        if (payload['id'] != id) {
          continue;
        }
        final error = payload['error'] as Map<Object?, Object?>?;
        if (error != null) {
          throw StateError(
            'serve-mcp $method failed: '
            '${jsonEncode(Map<String, Object?>.from(error))}',
          );
        }
        final result = payload['result'];
        if (result is! Map<Object?, Object?>) {
          throw StateError(
            'serve-mcp $method returned an unexpected payload.',
          );
        }
        return Map<String, Object?>.from(result);
      }
      throw StateError('serve-mcp closed before responding to $method.');
    }

    try {
      final initialize = await rpc('initialize', <String, Object?>{
        'protocolVersion': '2024-11-05',
        'capabilities': <String, Object?>{},
        'clientInfo': <String, Object?>{
          'name': 'flutter_cockpit verify_mcp_surface',
          'version': '1.0.0',
        },
      });
      channel.sink.add(
        jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        }),
      );
      final tools = await rpc('tools/list');
      final resources = await rpc('resources/list');
      final targets = await rpc('tools/call', <String, Object?>{
        'name': 'list_targets',
        'arguments': const <String, Object?>{},
      });

      final toolNames =
          ((tools['tools'] as List<Object?>?) ?? const <Object?>[])
              .whereType<Map<Object?, Object?>>()
              .map((tool) => '${tool['name']}')
              .toList(growable: false);
      if (!toolNames.contains('launch_app') ||
          !toolNames.contains('launch_target') ||
          !toolNames.contains('validate_task')) {
        throw StateError('serve-mcp did not expose the expected tool surface.');
      }

      return <String, Object?>{
        'logPath': logPath,
        'initialize': initialize,
        'toolNames': toolNames,
        'resourceNames':
            ((resources['resources'] as List<Object?>?) ?? const <Object?>[])
                .whereType<Map<Object?, Object?>>()
                .map((resource) => '${resource['name']}')
                .toList(growable: false),
        'listTargets': Map<String, Object?>.from(
          (targets['structuredContent'] as Map<Object?, Object?>?) ??
              const <Object?, Object?>{},
        ),
      };
    } finally {
      await channel.sink.close();
      await responses.cancel();
      await stderrSubscription.cancel();
      if (process.kill()) {
        await process.exitCode;
      } else {
        await process.exitCode.timeout(const Duration(seconds: 5));
      }
      if (stderrBuffer.isNotEmpty) {
        final stderrPath = p.join(verifyRoot, 'serve_mcp_stderr.log');
        File(stderrPath)
          ..createSync(recursive: true)
          ..writeAsStringSync(stderrBuffer.toString());
      }
    }
  }

  Map<String, Object?> _scriptJson({
    required String sessionId,
    required String taskId,
    required String screenshotName,
  }) {
    return <String, Object?>{
      'sessionId': sessionId,
      'taskId': taskId,
      'platform': 'macos',
      'environment': <String, Object?>{
        'platform': 'macos',
        'flutterVersion': '3.38.9',
        'dartVersion': '3.10.8',
      },
      'recording': <String, Object?>{
        'purpose': 'acceptance',
        'name': screenshotName,
        'tailStabilizationMs': 1400,
      },
      'commands': <Map<String, Object?>>[
        <String, Object?>{
          'commandId': 'open-today',
          'commandType': 'tap',
          'locator': <String, Object?>{
            'text': 'Today',
            'type': 'TextButton',
            'route': '/inbox',
          },
        },
        <String, Object?>{
          'commandId': 'wait-after-today',
          'commandType': 'waitForUiIdle',
        },
        <String, Object?>{
          'commandId': 'assert-today',
          'commandType': 'assertText',
          'parameters': <String, Object?>{'text': 'Today'},
        },
        <String, Object?>{
          'commandId': 'capture-today',
          'commandType': 'captureScreenshot',
          'screenshotRequest': <String, Object?>{
            'reason': 'acceptance',
            'name': screenshotName,
            'includeSnapshot': true,
            'attachToStep': true,
          },
        },
      ],
      'failFast': true,
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
        'projectDir': p.join(_repoRoot, 'examples', 'cockpit_demo'),
        'platform': 'macos',
        'deviceId': 'macos',
        'sessionPort': sessionPort,
      },
      'script': _scriptJson(
        sessionId: sessionId,
        taskId: taskId,
        screenshotName: screenshotName,
      ),
      'outputRoot': outputRoot,
      'baseline': <String, Object?>{
        'captureScreenshot': true,
        'screenshotName': 'baseline',
      },
      'requirements': <String, Object?>{
        'requireScreenshotEvidence': true,
        'requireVideoEvidence': true,
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
      'runTask': _runTaskJson(
        sessionPort: sessionPort,
        outputRoot: outputRoot,
        sessionId: sessionId,
        taskId: taskId,
        screenshotName: screenshotName,
      ),
      'validation': <String, Object?>{
        'expectedClassification': 'completed',
        'requireAcceptanceMarkdown': true,
        'requireEnvironmentSnapshot': true,
        'requirePrimaryScreenshot': true,
        'requirePrimaryRecording': true,
        'requireArtifactFiles': true,
        'requireAcceptanceSemanticEvidence': true,
      },
    };
  }
}
