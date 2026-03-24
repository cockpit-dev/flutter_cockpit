import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final String serverName;
  final String serverVersion;

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
            'tools': _tools.values
                .map((tool) => tool.toDescriptor())
                .toList(growable: false),
          });
        case 'tools/call':
          final params = _readParams(message);
          final toolName = _readString(params, 'name');
          final tool = _tools[toolName];
          if (tool == null) {
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

  Future<void> serveStdio({Stream<List<int>>? input, IOSink? output}) async {
    final reader = _CockpitMcpFrameReader();
    final source = input ?? stdin;
    final sink = output ?? stdout;

    await for (final chunk in source) {
      final frames = reader.addChunk(chunk);
      for (final frame in frames) {
        Map<String, Object?>? response;
        try {
          final decoded = jsonDecode(utf8.decode(frame));
          if (decoded is! Map<Object?, Object?>) {
            throw CockpitMcpError.invalidArguments(
              'MCP payload must be a JSON object.',
            );
          }
          response = await handleMessage(Map<String, Object?>.from(decoded));
        } on Object catch (error) {
          response = _errorResponse(
            null,
            error is CockpitMcpError
                ? error
                : CockpitMcpError.internal(
                    'Failed to process MCP frame.',
                    details: <String, Object?>{'error': error.toString()},
                  ),
          );
        }

        if (response != null) {
          _writeFrame(sink, response);
        }
      }
    }
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

  void _writeFrame(IOSink sink, Map<String, Object?> payload) {
    final body = utf8.encode(jsonEncode(payload));
    sink.write('Content-Length: ${body.length}\r\n\r\n');
    sink.add(body);
    sink.flush();
  }
}

final class _CockpitMcpFrameReader {
  final List<int> _buffer = <int>[];

  List<List<int>> addChunk(List<int> chunk) {
    _buffer.addAll(chunk);
    final frames = <List<int>>[];

    while (true) {
      final headerEnd = _indexOfHeaderTerminator(_buffer);
      if (headerEnd == -1) {
        break;
      }

      final headerBytes = _buffer.sublist(0, headerEnd);
      final headerText = ascii.decode(headerBytes);
      final contentLength = _readContentLength(headerText);
      final bodyStart = headerEnd + 4;
      final bodyEnd = bodyStart + contentLength;
      if (_buffer.length < bodyEnd) {
        break;
      }

      frames.add(_buffer.sublist(bodyStart, bodyEnd));
      _buffer.removeRange(0, bodyEnd);
    }

    return frames;
  }

  int _readContentLength(String headerText) {
    final lines = headerText.split('\r\n');
    for (final line in lines) {
      final separator = line.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      final name = line.substring(0, separator).trim().toLowerCase();
      if (name != 'content-length') {
        continue;
      }
      final value = int.tryParse(line.substring(separator + 1).trim());
      if (value == null || value < 0) {
        throw CockpitMcpError.invalidArguments(
          'Invalid Content-Length header.',
        );
      }
      return value;
    }
    throw CockpitMcpError.invalidArguments('Missing Content-Length header.');
  }

  int _indexOfHeaderTerminator(List<int> buffer) {
    for (var index = 0; index <= buffer.length - 4; index++) {
      if (buffer[index] == 13 &&
          buffer[index + 1] == 10 &&
          buffer[index + 2] == 13 &&
          buffer[index + 3] == 10) {
        return index;
      }
    }
    return -1;
  }
}
