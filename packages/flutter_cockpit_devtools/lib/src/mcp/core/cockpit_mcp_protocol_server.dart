import 'dart:async';

import 'package:dart_mcp/server.dart';

import '../cockpit_mcp_tool.dart';
import 'cockpit_mcp_tool_adapter.dart';

final class CockpitMcpProtocolServer extends MCPServer with ToolsSupport {
  CockpitMcpProtocolServer(
    super.channel, {
    required List<CockpitMcpTool> tools,
    required this.featureConfiguration,
    required this.serverName,
    required this.serverVersion,
    super.protocolLogSink,
  })  : _tools = List<CockpitMcpTool>.unmodifiable(tools),
        super.fromStreamChannel(
          implementation: Implementation(
            name: serverName,
            version: serverVersion,
          ),
          instructions:
              'Use these tools to manage flutter_cockpit sessions, task '
              'workflows, and evidence bundles.',
        ) {
    for (final tool in _enabledTools) {
      registerTool(
        CockpitMcpToolAdapter.protocolToolFor(tool),
        (request) => _invoke(tool, request),
      );
    }
  }

  final List<CockpitMcpTool> _tools;
  final CockpitMcpFeatureConfiguration featureConfiguration;
  final String serverName;
  final String serverVersion;

  List<CockpitMcpTool> get _enabledTools => _tools
      .where((tool) => featureConfiguration.isEnabled(tool.definition))
      .toList(growable: false);

  Future<CallToolResult> _invoke(
    CockpitMcpTool tool,
    CallToolRequest request,
  ) async {
    final progressToken = request.meta?.progressToken;
    if (progressToken != null && tool.definition.annotations.longRunning) {
      notifyProgress(
        ProgressNotification(
          progressToken: progressToken,
          progress: 0,
          total: 100,
          message: '${tool.name} started',
        ),
      );
    }

    final result = await CockpitMcpToolAdapter.invoke(
      tool,
      request.arguments ?? const <String, Object?>{},
    );

    if (progressToken != null && tool.definition.annotations.longRunning) {
      notifyProgress(
        ProgressNotification(
          progressToken: progressToken,
          progress: 100,
          total: 100,
          message: '${tool.name} completed',
        ),
      );
    }

    return result;
  }
}
