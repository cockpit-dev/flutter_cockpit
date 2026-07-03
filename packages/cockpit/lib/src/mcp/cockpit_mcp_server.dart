import 'dart:async';
import 'dart:io';

import 'package:dart_mcp/server.dart' show Root;
import 'package:path/path.dart' as p;
import 'package:stream_channel/stream_channel.dart';

import '../application/cockpit_latest_task_store.dart';
import '../application/cockpit_capture_screenshot_service.dart';
import '../application/cockpit_collect_development_probe_service.dart';
import '../application/cockpit_compare_development_probe_service.dart';
import '../application/cockpit_launch_app_service.dart';
import '../application/cockpit_launch_development_session_service.dart';
import '../application/cockpit_launch_remote_session_service.dart';
import '../application/cockpit_launch_target_service.dart';
import '../application/cockpit_list_active_sessions_service.dart';
import '../application/cockpit_list_apps_service.dart';
import '../application/cockpit_list_workspace_roots_service.dart';
import '../application/cockpit_execute_remote_command_batch_service.dart';
import '../application/cockpit_execute_remote_command_service.dart';
import '../application/cockpit_hot_reload_service.dart';
import '../application/cockpit_hot_restart_service.dart';
import '../application/cockpit_inspect_surface_service.dart';
import '../application/cockpit_inspect_ui_service.dart';
import '../application/cockpit_interactive_session_lock.dart';
import '../application/cockpit_interactive_snapshot_store.dart';
import '../application/cockpit_read_latest_task_summary_service.dart';
import '../application/cockpit_read_app_service.dart';
import '../application/cockpit_read_target_service.dart';
import '../application/cockpit_read_logs_service.dart';
import '../application/cockpit_read_network_service.dart';
import '../application/cockpit_read_remote_snapshot_service.dart';
import '../application/cockpit_read_remote_status_service.dart';
import '../application/cockpit_read_runtime_errors_service.dart';
import '../application/cockpit_query_development_session_service.dart';
import '../application/cockpit_query_remote_session_service.dart';
import '../application/cockpit_read_session_logs_service.dart';
import '../application/cockpit_reload_development_session_service.dart';
import '../application/cockpit_run_shell_service.dart';
import '../application/cockpit_run_batch_service.dart';
import '../application/cockpit_run_command_service.dart';
import '../application/cockpit_session_registry.dart';
import '../application/cockpit_start_recording_service.dart';
import '../application/cockpit_start_remote_recording_service.dart';
import '../application/cockpit_stop_app_service.dart';
import '../application/cockpit_stop_development_session_service.dart';
import '../application/cockpit_stop_recording_service.dart';
import '../application/cockpit_stop_remote_recording_service.dart';
import '../application/cockpit_wait_idle_service.dart';
import '../application/cockpit_wait_remote_ui_idle_service.dart';
import '../system_control/cockpit_system_control_action_service.dart';
import '../system_control/cockpit_system_control_service.dart';
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
import 'resources/cockpit_apps_resource.dart';
import 'resources/cockpit_latest_task_resource.dart';
import 'resources/cockpit_package_uri_resource.dart';
import 'resources/cockpit_task_bundle_summary_resource.dart';
import 'resources/cockpit_workspace_capabilities_resource.dart';
import 'resources/cockpit_workspace_contracts_resource.dart';
import 'resources/cockpit_workspace_roots_resource.dart';
import 'tools/cockpit_add_roots_tool.dart';
import 'tools/cockpit_analyze_files_tool.dart';
import 'tools/cockpit_analyze_workspace_tool.dart';
import 'tools/cockpit_apply_workspace_fixes_tool.dart';
import 'tools/cockpit_capture_screenshot_tool.dart';
import 'tools/cockpit_collect_development_probe_tool.dart';
import 'tools/cockpit_collect_remote_snapshot_tool.dart';
import 'tools/cockpit_compare_development_probe_tool.dart';
import 'tools/cockpit_create_project_tool.dart';
import 'tools/cockpit_execute_remote_command_batch_tool.dart';
import 'tools/cockpit_execute_remote_command_tool.dart';
import 'tools/cockpit_format_workspace_tool.dart';
import 'tools/cockpit_grep_package_uris_tool.dart';
import 'tools/cockpit_hot_reload_tool.dart';
import 'tools/cockpit_hot_restart_tool.dart';
import 'tools/cockpit_inspect_ui_tool.dart';
import 'tools/cockpit_inspect_surface_tool.dart';
import 'tools/cockpit_lsp_tool.dart';
import 'tools/cockpit_launch_app_tool.dart';
import 'tools/cockpit_launch_development_session_tool.dart';
import 'tools/cockpit_launch_remote_session_tool.dart';
import 'tools/cockpit_launch_target_tool.dart';
import 'tools/cockpit_list_active_sessions_tool.dart';
import 'tools/cockpit_list_apps_tool.dart';
import 'tools/cockpit_list_launch_targets_tool.dart';
import 'tools/cockpit_pub_dev_search_tool.dart';
import 'tools/cockpit_pub_tool.dart';
import 'tools/cockpit_read_app_tool.dart';
import 'tools/cockpit_read_target_tool.dart';
import 'tools/cockpit_read_logs_tool.dart';
import 'tools/cockpit_read_network_tool.dart';
import 'tools/cockpit_read_package_uris_tool.dart';
import 'tools/cockpit_query_development_session_tool.dart';
import 'tools/cockpit_query_remote_session_tool.dart';
import 'tools/cockpit_read_remote_snapshot_tool.dart';
import 'tools/cockpit_read_remote_status_tool.dart';
import 'tools/cockpit_read_runtime_errors_tool.dart';
import 'tools/cockpit_read_session_logs_tool.dart';
import 'tools/cockpit_read_system_capabilities_tool.dart';
import 'tools/cockpit_read_task_bundle_summary_tool.dart';
import 'tools/cockpit_remove_roots_tool.dart';
import 'tools/cockpit_reload_development_session_tool.dart';
import 'tools/cockpit_run_batch_tool.dart';
import 'tools/cockpit_run_command_tool.dart';
import 'tools/cockpit_run_shell_tool.dart';
import 'tools/cockpit_run_system_action_tool.dart';
import 'tools/cockpit_run_workspace_tests_tool.dart';
import 'tools/cockpit_run_remote_control_script_tool.dart';
import 'tools/cockpit_run_task_tool.dart';
import 'tools/cockpit_start_recording_tool.dart';
import 'tools/cockpit_start_remote_recording_tool.dart';
import 'tools/cockpit_stop_app_tool.dart';
import 'tools/cockpit_stop_development_session_tool.dart';
import 'tools/cockpit_stop_recording_tool.dart';
import 'tools/cockpit_stop_remote_recording_tool.dart';
import 'tools/cockpit_validate_task_tool.dart';
import 'tools/cockpit_wait_idle_tool.dart';
import 'tools/cockpit_wait_remote_ui_idle_tool.dart';
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
    this.serverName = 'cockpit',
    this.serverVersion = '1.1.1',
  }) : rootsTracker = rootsTracker ?? CockpitMcpRootsTracker(),
       sessionRegistry = sessionRegistry ?? CockpitSessionRegistry(),
       latestTaskStore = latestTaskStore ?? CockpitLatestTaskStore(),
       _tools = Map<String, CockpitMcpTool>.fromEntries(
         tools.map((tool) => MapEntry(tool.name, tool)),
       );

  factory CockpitMcpServer.standard({
    String serverName = 'cockpit',
    String serverVersion = '1.1.1',
    String protocolPath = 'docs/contracts/flutter-cockpit-protocol.md',
    String aiDevelopmentProtocolPath =
        'docs/contracts/ai-development-protocol.md',
    String skillContractPath =
        'docs/contracts/flutter-cockpit-skill-contract.md',
    String bundleContractPath = 'docs/contracts/task-run-bundle.md',
    String workflowProtocolPath = 'docs/contracts/control-workflow-protocol.md',
    String workflowSchemaPath = 'docs/contracts/control-workflow.schema.json',
    CockpitMcpFeatureConfiguration featureConfiguration =
        const CockpitMcpFeatureConfiguration(),
    bool forceRootsFallback = false,
    List<String> workspaceRoots = const <String>[],
  }) {
    final rootsTracker = CockpitMcpRootsTracker(
      forceFallback: forceRootsFallback,
    );
    final resolvedProtocolPath = _resolveWorkspacePathForStandardServer(
      protocolPath,
      workspaceRoots: workspaceRoots,
    );
    final resolvedAiDevelopmentProtocolPath =
        _resolveWorkspacePathForStandardServer(
          aiDevelopmentProtocolPath,
          workspaceRoots: workspaceRoots,
        );
    final resolvedSkillContractPath = _resolveWorkspacePathForStandardServer(
      skillContractPath,
      workspaceRoots: workspaceRoots,
    );
    final resolvedBundleContractPath = _resolveWorkspacePathForStandardServer(
      bundleContractPath,
      workspaceRoots: workspaceRoots,
    );
    final resolvedWorkflowProtocolPath = _resolveWorkspacePathForStandardServer(
      workflowProtocolPath,
      workspaceRoots: workspaceRoots,
    );
    final resolvedWorkflowSchemaPath = _resolveWorkspacePathForStandardServer(
      workflowSchemaPath,
      workspaceRoots: workspaceRoots,
    );
    if (workspaceRoots.isNotEmpty) {
      rootsTracker.addFallbackRoots(
        workspaceRoots.map(
          (root) => Root(
            uri: Uri.directory(p.normalize(root)).toString(),
            name: p.basename(root),
          ),
        ),
      );
    }
    final sessionRegistry = CockpitSessionRegistry();
    final latestTaskStore = CockpitLatestTaskStore();
    final interactiveSnapshotStore = CockpitInteractiveSnapshotStore();
    final interactiveSessionLock = CockpitInteractiveSessionLock();
    final readLatestTaskSummaryService = CockpitReadLatestTaskSummaryService(
      store: latestTaskStore,
    );
    final listActiveSessionsService = CockpitListActiveSessionsService(
      registry: sessionRegistry,
    );
    final listAppsService = CockpitListAppsService(registry: sessionRegistry);
    final readLogsService = CockpitReadLogsService(registry: sessionRegistry);
    final readNetworkService = CockpitReadNetworkService(
      registry: sessionRegistry,
    );
    final readRuntimeErrorsService = CockpitReadRuntimeErrorsService(
      registry: sessionRegistry,
      latestTaskStore: latestTaskStore,
    );
    final launchRemoteSessionService = CockpitLaunchRemoteSessionService();
    final queryRemoteSessionService = CockpitQueryRemoteSessionService();
    final launchDevelopmentSessionService =
        CockpitLaunchDevelopmentSessionService();
    final queryDevelopmentSessionService =
        CockpitQueryDevelopmentSessionService();
    final reloadDevelopmentSessionService =
        CockpitReloadDevelopmentSessionService();
    final stopDevelopmentSessionService =
        CockpitStopDevelopmentSessionService();
    final readSessionLogsService = CockpitReadSessionLogsService(
      registry: sessionRegistry,
    );
    final collectDevelopmentProbeService =
        CockpitCollectDevelopmentProbeService();
    const compareDevelopmentProbeService =
        CockpitCompareDevelopmentProbeService();
    final executeRemoteCommandService = CockpitExecuteRemoteCommandService(
      snapshotStore: interactiveSnapshotStore,
      sessionLock: interactiveSessionLock,
    );
    final executeRemoteCommandBatchService =
        CockpitExecuteRemoteCommandBatchService(
          snapshotStore: interactiveSnapshotStore,
          sessionLock: interactiveSessionLock,
        );
    final readRemoteStatusService = CockpitReadRemoteStatusService(
      snapshotStore: interactiveSnapshotStore,
    );
    final readRemoteSnapshotService = CockpitReadRemoteSnapshotService(
      snapshotStore: interactiveSnapshotStore,
    );
    final waitRemoteUiIdleService = CockpitWaitRemoteUiIdleService(
      sessionLock: interactiveSessionLock,
    );
    final startRemoteRecordingService = CockpitStartRemoteRecordingService(
      sessionLock: interactiveSessionLock,
    );
    final stopRemoteRecordingService = CockpitStopRemoteRecordingService(
      sessionLock: interactiveSessionLock,
    );
    final launchAppService = CockpitLaunchAppService(registry: sessionRegistry);
    final launchTargetService = CockpitLaunchTargetService(
      launchAppService: launchAppService,
    );
    final hotReloadService = CockpitHotReloadService(registry: sessionRegistry);
    final hotRestartService = CockpitHotRestartService(
      registry: sessionRegistry,
    );
    final stopAppService = CockpitStopAppService(registry: sessionRegistry);
    final readAppService = CockpitReadAppService(
      remoteStatusService: readRemoteStatusService,
      registry: sessionRegistry,
    );
    final readTargetService = CockpitReadTargetService(
      readAppService: readAppService,
    );
    final inspectUiService = CockpitInspectUiService(
      snapshotService: readRemoteSnapshotService,
      registry: sessionRegistry,
    );
    final inspectSurfaceService = CockpitInspectSurfaceService(
      inspectUiService: inspectUiService,
    );
    final runCommandService = CockpitRunCommandService(
      executeService: executeRemoteCommandService,
      registry: sessionRegistry,
    );
    final captureScreenshotService = CockpitCaptureScreenshotService(
      runCommandService: runCommandService,
    );
    final waitIdleService = CockpitWaitIdleService(
      waitService: waitRemoteUiIdleService,
      registry: sessionRegistry,
    );
    final startRecordingService = CockpitStartRecordingService(
      startService: startRemoteRecordingService,
      registry: sessionRegistry,
    );
    final stopRecordingService = CockpitStopRecordingService(
      stopService: stopRemoteRecordingService,
      registry: sessionRegistry,
    );
    final runBatchService = CockpitRunBatchService(
      executeService: executeRemoteCommandBatchService,
      startRecordingService: startRecordingService,
      stopRecordingService: stopRecordingService,
      registry: sessionRegistry,
    );
    final runShellService = CockpitRunShellService();
    final systemControlService = CockpitSystemControlService();
    final systemControlActionService = CockpitSystemControlActionService(
      systemControlService: systemControlService,
    );
    final tools = <CockpitMcpTool>[
      CockpitAddRootsTool(rootsTracker: rootsTracker),
      CockpitRemoveRootsTool(rootsTracker: rootsTracker),
      CockpitListLaunchTargetsTool(),
      CockpitListActiveSessionsTool(service: listActiveSessionsService),
      CockpitLaunchAppTool(service: launchAppService),
      CockpitLaunchTargetTool(service: launchTargetService),
      CockpitLaunchRemoteSessionTool(
        service: launchRemoteSessionService,
        sessionRegistry: sessionRegistry,
      ),
      CockpitQueryRemoteSessionTool(
        service: queryRemoteSessionService,
        sessionRegistry: sessionRegistry,
      ),
      CockpitReadRemoteStatusTool(service: readRemoteStatusService),
      CockpitReadRemoteSnapshotTool(service: readRemoteSnapshotService),
      CockpitCollectRemoteSnapshotTool(),
      CockpitListAppsTool(service: listAppsService),
      CockpitLaunchDevelopmentSessionTool(
        service: launchDevelopmentSessionService,
        sessionRegistry: sessionRegistry,
      ),
      CockpitQueryDevelopmentSessionTool(
        service: queryDevelopmentSessionService,
        sessionRegistry: sessionRegistry,
      ),
      CockpitReloadDevelopmentSessionTool(
        service: reloadDevelopmentSessionService,
        sessionRegistry: sessionRegistry,
      ),
      CockpitCollectDevelopmentProbeTool(
        service: collectDevelopmentProbeService,
      ),
      CockpitCompareDevelopmentProbeTool(
        service: compareDevelopmentProbeService,
      ),
      CockpitReadSessionLogsTool(service: readSessionLogsService),
      CockpitStopDevelopmentSessionTool(
        service: stopDevelopmentSessionService,
        sessionRegistry: sessionRegistry,
      ),
      CockpitHotReloadTool(service: hotReloadService),
      CockpitHotRestartTool(service: hotRestartService),
      CockpitStopAppTool(service: stopAppService),
      CockpitReadAppTool(service: readAppService),
      CockpitReadTargetTool(service: readTargetService),
      CockpitInspectUiTool(service: inspectUiService),
      CockpitInspectSurfaceTool(service: inspectSurfaceService),
      CockpitRunCommandTool(service: runCommandService),
      CockpitCaptureScreenshotTool(service: captureScreenshotService),
      CockpitRunBatchTool(service: runBatchService),
      CockpitExecuteRemoteCommandTool(service: executeRemoteCommandService),
      CockpitExecuteRemoteCommandBatchTool(
        service: executeRemoteCommandBatchService,
      ),
      CockpitReadSystemCapabilitiesTool(service: systemControlService),
      CockpitRunSystemActionTool(service: systemControlActionService),
      CockpitRunShellTool(service: runShellService),
      CockpitWaitIdleTool(service: waitIdleService),
      CockpitWaitRemoteUiIdleTool(service: waitRemoteUiIdleService),
      CockpitStartRecordingTool(service: startRecordingService),
      CockpitStopRecordingTool(service: stopRecordingService),
      CockpitStartRemoteRecordingTool(service: startRemoteRecordingService),
      CockpitStopRemoteRecordingTool(service: stopRemoteRecordingService),
      CockpitReadLogsTool(service: readLogsService),
      CockpitReadNetworkTool(service: readNetworkService),
      CockpitReadRuntimeErrorsTool(service: readRuntimeErrorsService),
      CockpitRunRemoteControlScriptTool(registry: sessionRegistry),
      CockpitReadTaskBundleSummaryTool(),
      CockpitRunTaskTool(latestTaskStore: latestTaskStore),
      CockpitValidateTaskTool(),
      CockpitPubDevSearchTool(),
      CockpitPubTool(rootsTracker: rootsTracker),
      CockpitReadPackageUrisTool(rootsTracker: rootsTracker),
      CockpitGrepPackageUrisTool(rootsTracker: rootsTracker),
      CockpitLspTool(rootsTracker: rootsTracker),
      CockpitAnalyzeFilesTool(rootsTracker: rootsTracker),
      CockpitCreateProjectTool(rootsTracker: rootsTracker),
      CockpitAnalyzeWorkspaceTool(rootsTracker: rootsTracker),
      CockpitFormatWorkspaceTool(rootsTracker: rootsTracker),
      CockpitRunWorkspaceTestsTool(rootsTracker: rootsTracker),
      CockpitApplyWorkspaceFixesTool(rootsTracker: rootsTracker),
    ];
    final prompts = const <CockpitMcpPrompt>[
      CockpitRunClosedLoopTaskPrompt(),
      CockpitInspectBeforeClaimingDonePrompt(),
      CockpitRecoverFromFailedValidationPrompt(),
      CockpitPrepareAcceptanceDeliveryPrompt(),
      CockpitCreateProjectWithValidationPrompt(),
    ];
    final baseResources = <CockpitMcpResource>[
      CockpitWorkspaceProtocolResource(protocolPath: resolvedProtocolPath),
      CockpitWorkspaceAiDevelopmentProtocolResource(
        aiDevelopmentProtocolPath: resolvedAiDevelopmentProtocolPath,
      ),
      CockpitWorkspaceSkillContractResource(
        skillContractPath: resolvedSkillContractPath,
      ),
      CockpitWorkspaceTaskBundleContractResource(
        bundleContractPath: resolvedBundleContractPath,
      ),
      CockpitWorkspaceWorkflowProtocolResource(
        workflowProtocolPath: resolvedWorkflowProtocolPath,
      ),
      CockpitWorkspaceWorkflowSchemaResource(
        workflowSchemaPath: resolvedWorkflowSchemaPath,
      ),
      CockpitWorkspaceRootsResource(
        service: CockpitListWorkspaceRootsService(rootsTracker: rootsTracker),
      ),
      CockpitAppsResource(service: listAppsService),
      CockpitAppResource(registry: sessionRegistry),
      CockpitLatestTaskResource(service: readLatestTaskSummaryService),
      CockpitTaskBundleSummaryResource(),
      CockpitPackageUriResource(rootsTracker: rootsTracker),
    ];
    final resources = <CockpitMcpResource>[
      ...baseResources,
      CockpitWorkspaceCapabilitiesResource(
        serverName: serverName,
        serverVersion: serverVersion,
        featureConfiguration: featureConfiguration,
        rootsTracker: rootsTracker,
        tools: tools,
        resources: baseResources,
        prompts: prompts,
      ),
    ];
    return CockpitMcpServer(
      serverName: serverName,
      serverVersion: serverVersion,
      featureConfiguration: featureConfiguration,
      rootsTracker: rootsTracker,
      sessionRegistry: sessionRegistry,
      latestTaskStore: latestTaskStore,
      tools: tools,
      resources: resources,
      prompts: prompts,
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

  List<CockpitMcpResource> get _enabledResources => resources
      .where((resource) => featureConfiguration.isEnabled(resource.definition))
      .toList(growable: false);

  List<CockpitMcpPrompt> get _enabledPrompts => prompts
      .where((prompt) => featureConfiguration.isEnabled(prompt.definition))
      .toList(growable: false);

  CockpitMcpProtocolServer createProtocolServer(
    StreamChannel<String> channel, {
    Sink<String>? protocolLogSink,
  }) {
    return CockpitMcpProtocolServer(
      channel,
      tools: _enabledTools,
      resources: _enabledResources,
      prompts: _enabledPrompts,
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
            'protocolVersion':
                ((message['params']
                        as Map<Object?, Object?>?)?['protocolVersion']
                    as String?) ??
                '2024-11-05',
            'capabilities': <String, Object?>{
              'tools': <String, Object?>{},
              'resources': <String, Object?>{},
              'prompts': <String, Object?>{},
              'roots': <String, Object?>{'listChanged': true},
            },
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
        case 'resources/list':
          return _successResponse(id, <String, Object?>{
            'resources': _enabledResources
                .where((resource) => !resource.definition.isTemplate)
                .map(
                  (resource) => <String, Object?>{
                    'name': resource.definition.name,
                    'uri': resource.definition.uri,
                    'description': resource.definition.description,
                    'mimeType': resource.definition.mimeType,
                  },
                )
                .toList(growable: false),
          });
        case 'resources/templates/list':
          return _successResponse(id, <String, Object?>{
            'resourceTemplates': _enabledResources
                .where((resource) => resource.definition.isTemplate)
                .map(
                  (resource) => <String, Object?>{
                    'name': resource.definition.name,
                    'uriTemplate': resource.definition.uriTemplate,
                    'description': resource.definition.description,
                    'mimeType': resource.definition.mimeType,
                  },
                )
                .toList(growable: false),
          });
        case 'resources/read':
          final params = _readParams(message);
          final resourceUri = _readString(params, 'uri');
          final resourceResult = await _readResource(resourceUri);
          return _successResponse(id, <String, Object?>{
            'contents': resourceResult.contents
                .map(
                  (content) => switch (content) {
                    CockpitMcpTextResourceContents() => <String, Object?>{
                      'uri': content.uri,
                      'mimeType': content.mimeType,
                      'text': content.text,
                    },
                  },
                )
                .toList(growable: false),
          });
        case 'prompts/list':
          return _successResponse(id, <String, Object?>{
            'prompts': _enabledPrompts
                .map(
                  (prompt) => <String, Object?>{
                    'name': prompt.definition.name,
                    'description': prompt.definition.description,
                    'arguments': prompt.definition.arguments
                        .map(
                          (argument) => <String, Object?>{
                            'name': argument.name,
                            'description': argument.description,
                            'required': argument.required,
                          },
                        )
                        .toList(growable: false),
                  },
                )
                .toList(growable: false),
          });
        case 'prompts/get':
          final params = _readParams(message);
          final promptName = _readString(params, 'name');
          final promptArguments = params['arguments'] is Map<Object?, Object?>
              ? Map<String, Object?>.from(
                  params['arguments']! as Map<Object?, Object?>,
                )
              : const <String, Object?>{};
          final promptResult = await _getPrompt(promptName, promptArguments);
          return _successResponse(id, <String, Object?>{
            'description': promptResult.description,
            'messages': promptResult.messages
                .map(
                  (message) => <String, Object?>{
                    'role': message.role.name,
                    'content': <String, Object?>{
                      'type': 'text',
                      'text': message.text,
                    },
                  },
                )
                .toList(growable: false),
          });
        case 'roots/list':
          return _successResponse(id, <String, Object?>{
            'roots': rootsTracker.effectiveRoots
                .map(
                  (root) => <String, Object?>{
                    'uri': root.uri,
                    if (root.name != null) 'name': root.name!,
                  },
                )
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
      cockpitMcpStdioChannel(input: input ?? stdin, output: output ?? stdout),
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

  Future<CockpitMcpResourceResult> _readResource(String uri) async {
    for (final resource in _enabledResources) {
      final result = await resource.read(CockpitMcpResourceRequest(uri: uri));
      if (result != null) {
        return result;
      }
    }
    throw CockpitMcpError.invalidArguments(
      'Unknown MCP resource.',
      details: <String, Object?>{'uri': uri},
    );
  }

  Future<CockpitMcpPromptResult> _getPrompt(
    String name,
    Map<String, Object?> arguments,
  ) async {
    for (final prompt in _enabledPrompts) {
      if (prompt.definition.name == name) {
        return prompt.build(arguments);
      }
    }
    throw CockpitMcpError.invalidArguments(
      'Unknown MCP prompt.',
      details: <String, Object?>{'name': name},
    );
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

String _resolveWorkspacePathForStandardServer(
  String candidate, {
  required List<String> workspaceRoots,
}) {
  if (p.isAbsolute(candidate)) {
    return p.normalize(candidate);
  }
  if (workspaceRoots.isNotEmpty) {
    return p.normalize(p.join(workspaceRoots.first, candidate));
  }
  return p.normalize(candidate);
}
