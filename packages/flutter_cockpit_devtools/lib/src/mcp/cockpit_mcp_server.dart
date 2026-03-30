import 'dart:async';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

import '../application/cockpit_latest_task_store.dart';
import '../application/cockpit_list_active_sessions_service.dart';
import '../application/cockpit_list_workspace_roots_service.dart';
import '../application/cockpit_read_latest_task_summary_service.dart';
import '../application/cockpit_session_registry.dart';
import 'core/cockpit_mcp_protocol_server.dart';
import 'core/cockpit_mcp_prompt.dart';
import 'core/cockpit_mcp_resource.dart';
import 'core/cockpit_mcp_roots_tracker.dart';
import 'core/cockpit_mcp_stdio_channel.dart';
import 'prompts/cockpit_create_project_with_validation_prompt.dart';
import 'prompts/cockpit_inspect_before_claiming_done_prompt.dart';
import 'prompts/cockpit_prepare_acceptance_delivery_prompt.dart';
import 'prompts/cockpit_recover_from_failed_validation_prompt.dart';
import 'prompts/cockpit_run_closed_loop_task_prompt.dart';
import 'resources/cockpit_active_sessions_resource.dart';
import 'resources/cockpit_latest_task_resource.dart';
import 'resources/cockpit_workspace_capabilities_resource.dart';
import 'resources/cockpit_workspace_contracts_resource.dart';
import 'resources/cockpit_workspace_goals_resource.dart';
import 'resources/cockpit_workspace_roots_resource.dart';
import 'tools/cockpit_collect_development_probe_tool.dart';
import 'tools/cockpit_launch_remote_session_tool.dart';
import 'tools/cockpit_compare_development_probe_tool.dart';
import 'tools/cockpit_launch_development_session_tool.dart';
import 'tools/cockpit_collect_remote_snapshot_tool.dart';
import 'tools/cockpit_query_development_session_tool.dart';
import 'tools/cockpit_query_remote_session_tool.dart';
import 'tools/cockpit_read_task_bundle_summary_tool.dart';
import 'tools/cockpit_reload_development_session_tool.dart';
import 'tools/cockpit_run_remote_control_script_tool.dart';
import 'tools/cockpit_run_task_tool.dart';
import 'tools/cockpit_stop_development_session_tool.dart';
import 'tools/cockpit_validate_task_tool.dart';
import 'cockpit_mcp_error.dart';
import 'cockpit_mcp_tool.dart';

final class CockpitMcpServer {
  CockpitMcpServer({
    required List<CockpitMcpTool> tools,
    this.resources = const <CockpitMcpResource>[],
    this.prompts = const <CockpitMcpPrompt>[],
    this.featureConfiguration = const CockpitMcpFeatureConfiguration(),
    CockpitMcpRootsTracker? rootsTracker,
    CockpitSessionRegistry? sessionRegistry,
    CockpitLatestTaskStore? latestTaskStore,
    this.serverName = 'flutter_cockpit_devtools',
    this.serverVersion = '1.0.0',
  })  : rootsTracker = rootsTracker ?? CockpitMcpRootsTracker(),
        sessionRegistry = sessionRegistry ?? CockpitSessionRegistry(),
        latestTaskStore = latestTaskStore ?? CockpitLatestTaskStore(),
        _tools = Map<String, CockpitMcpTool>.fromEntries(
          tools.map((tool) => MapEntry(tool.name, tool)),
        );

  factory CockpitMcpServer.standard({
    String serverName = 'flutter_cockpit_devtools',
    String serverVersion = '1.0.0',
    String goalsFilePath = 'GOALS.md',
    String skillContractPath =
        'docs/contracts/flutter-cockpit-skill-contract.md',
    String bundleContractPath = 'docs/contracts/task-run-bundle.md',
    bool forceRootsFallback = false,
  }) {
    final rootsTracker = CockpitMcpRootsTracker(
      forceFallback: forceRootsFallback,
    );
    final sessionRegistry = CockpitSessionRegistry();
    final latestTaskStore = CockpitLatestTaskStore();
    return CockpitMcpServer(
      serverName: serverName,
      serverVersion: serverVersion,
      rootsTracker: rootsTracker,
      sessionRegistry: sessionRegistry,
      latestTaskStore: latestTaskStore,
      tools: <CockpitMcpTool>[
        CockpitLaunchDevelopmentSessionTool(sessionRegistry: sessionRegistry),
        CockpitQueryDevelopmentSessionTool(sessionRegistry: sessionRegistry),
        CockpitReloadDevelopmentSessionTool(sessionRegistry: sessionRegistry),
        CockpitStopDevelopmentSessionTool(sessionRegistry: sessionRegistry),
        CockpitCollectDevelopmentProbeTool(),
        CockpitCompareDevelopmentProbeTool(),
        CockpitLaunchRemoteSessionTool(sessionRegistry: sessionRegistry),
        CockpitCollectRemoteSnapshotTool(),
        CockpitQueryRemoteSessionTool(sessionRegistry: sessionRegistry),
        CockpitRunRemoteControlScriptTool(),
        CockpitReadTaskBundleSummaryTool(),
        CockpitRunTaskTool(latestTaskStore: latestTaskStore),
        CockpitValidateTaskTool(),
      ],
      resources: <CockpitMcpResource>[
        CockpitWorkspaceGoalsResource(goalsFilePath: goalsFilePath),
        CockpitWorkspaceSkillContractResource(
          skillContractPath: skillContractPath,
        ),
        CockpitWorkspaceTaskBundleContractResource(
          bundleContractPath: bundleContractPath,
        ),
        CockpitWorkspaceRootsResource(
          service: CockpitListWorkspaceRootsService(
            rootsTracker: rootsTracker,
          ),
        ),
        CockpitWorkspaceCapabilitiesResource(
          serverName: serverName,
          serverVersion: serverVersion,
          featureConfiguration: const CockpitMcpFeatureConfiguration(),
        ),
        CockpitActiveSessionsResource(
          service: CockpitListActiveSessionsService(
            registry: sessionRegistry,
          ),
        ),
        CockpitLatestTaskResource(
          service: CockpitReadLatestTaskSummaryService(store: latestTaskStore),
        ),
      ],
      prompts: const <CockpitMcpPrompt>[
        CockpitRunClosedLoopTaskPrompt(),
        CockpitInspectBeforeClaimingDonePrompt(),
        CockpitRecoverFromFailedValidationPrompt(),
        CockpitPrepareAcceptanceDeliveryPrompt(),
        CockpitCreateProjectWithValidationPrompt(),
      ],
    );
  }

  final Map<String, CockpitMcpTool> _tools;
  final List<CockpitMcpResource> resources;
  final List<CockpitMcpPrompt> prompts;
  final CockpitMcpFeatureConfiguration featureConfiguration;
  final CockpitMcpRootsTracker rootsTracker;
  final CockpitSessionRegistry sessionRegistry;
  final CockpitLatestTaskStore latestTaskStore;
  final String serverName;
  final String serverVersion;

  List<CockpitMcpTool> get _enabledTools => _tools.values
      .where((tool) => featureConfiguration.isEnabled(tool.definition))
      .toList(growable: false);

  CockpitMcpProtocolServer createProtocolServer(
    StreamChannel<String> channel, {
    Sink<String>? protocolLogSink,
  }) {
    return CockpitMcpProtocolServer(
      channel,
      tools: _enabledTools,
      resources: resources,
      prompts: prompts,
      rootsTracker: rootsTracker,
      featureConfiguration: featureConfiguration,
      serverName: serverName,
      serverVersion: serverVersion,
      protocolLogSink: protocolLogSink,
    );
  }

  Future<Map<String, Object?>?> handleMessage(
    Map<String, Object?> message,
  ) async {
    final id = message['id'];
    final method = message['method'];
    if (method is! String || method.isEmpty) {
      return id == null
          ? null
          : _errorResponse(
              id,
              CockpitMcpError.invalidArguments('MCP method is required.'),
            );
    }

    try {
      switch (method) {
        case 'initialize':
          return _successResponse(id, <String, Object?>{
            'protocolVersion': ((message['params']
                        as Map<Object?, Object?>?)?['protocolVersion']
                    as String?) ??
                '2024-11-05',
            'capabilities': <String, Object?>{'tools': <String, Object?>{}},
            'serverInfo': <String, Object?>{
              'name': serverName,
              'version': serverVersion,
            },
          });
        case 'notifications/initialized':
        case 'initialized':
          return null;
        case 'tools/list':
          return _successResponse(id, <String, Object?>{
            'tools': _enabledTools
                .map((tool) => tool.toDescriptor())
                .toList(growable: false),
          });
        case 'tools/call':
          final params = _readParams(message);
          final toolName = _readString(params, 'name');
          final tool = _tools[toolName];
          if (tool == null ||
              !featureConfiguration.isEnabled(tool.definition)) {
            throw CockpitMcpError.invalidArguments(
              'Unknown MCP tool.',
              details: <String, Object?>{'tool': toolName},
            );
          }
          final arguments = params['arguments'];
          final normalizedArguments = arguments is Map<Object?, Object?>
              ? Map<String, Object?>.from(arguments)
              : <String, Object?>{};
          final result = await tool.call(normalizedArguments);
          return _successResponse(id, result);
        default:
          throw CockpitMcpError.methodNotFound(method);
      }
    } on Object catch (error) {
      if (id == null) {
        return null;
      }
      final mcpError = error is CockpitMcpError
          ? error
          : CockpitMcpError.internal(
              'Unexpected MCP server failure.',
              details: <String, Object?>{'error': error.toString()},
            );
      return _errorResponse(id, mcpError);
    }
  }

  Future<void> serveStdio({
    Stream<List<int>>? input,
    StreamSink<List<int>>? output,
    Sink<String>? protocolLogSink,
  }) async {
    final server = createProtocolServer(
      cockpitMcpStdioChannel(
        input: input ?? stdin,
        output: output ?? stdout,
      ),
      protocolLogSink: protocolLogSink,
    );
    await server.done;
  }

  Map<String, Object?> _successResponse(
    Object? id,
    Map<String, Object?> result,
  ) {
    return <String, Object?>{'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  Map<String, Object?> _errorResponse(Object? id, CockpitMcpError error) {
    return <String, Object?>{
      'jsonrpc': '2.0',
      'id': id,
      'error': error.toJson(),
    };
  }

  Map<String, Object?> _readParams(Map<String, Object?> message) {
    final params = message['params'];
    if (params == null) {
      return const <String, Object?>{};
    }
    if (params is Map<Object?, Object?>) {
      return Map<String, Object?>.from(params);
    }
    throw CockpitMcpError.invalidArguments('MCP params must be an object.');
  }

  String _readString(Map<String, Object?> params, String key) {
    final value = params[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw CockpitMcpError.invalidArguments(
      'MCP string parameter is required.',
      details: <String, Object?>{'parameter': key},
    );
  }
}
