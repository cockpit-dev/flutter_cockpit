import 'dart:async';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

import 'core/cockpit_mcp_protocol_server.dart';
import 'core/cockpit_mcp_stdio_channel.dart';
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
    this.featureConfiguration = const CockpitMcpFeatureConfiguration(),
    this.serverName = 'flutter_cockpit_devtools',
    this.serverVersion = '1.0.0',
  }) : _tools = Map<String, CockpitMcpTool>.fromEntries(
          tools.map((tool) => MapEntry(tool.name, tool)),
        );

  factory CockpitMcpServer.standard({
    String serverName = 'flutter_cockpit_devtools',
    String serverVersion = '1.0.0',
  }) {
    return CockpitMcpServer(
      serverName: serverName,
      serverVersion: serverVersion,
      tools: <CockpitMcpTool>[
        CockpitLaunchDevelopmentSessionTool(),
        CockpitQueryDevelopmentSessionTool(),
        CockpitReloadDevelopmentSessionTool(),
        CockpitStopDevelopmentSessionTool(),
        CockpitCollectDevelopmentProbeTool(),
        CockpitCompareDevelopmentProbeTool(),
        CockpitLaunchRemoteSessionTool(),
        CockpitCollectRemoteSnapshotTool(),
        CockpitQueryRemoteSessionTool(),
        CockpitRunRemoteControlScriptTool(),
        CockpitReadTaskBundleSummaryTool(),
        CockpitRunTaskTool(),
        CockpitValidateTaskTool(),
      ],
    );
  }

  final Map<String, CockpitMcpTool> _tools;
  final CockpitMcpFeatureConfiguration featureConfiguration;
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
