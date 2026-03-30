import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_server.dart';
import 'package:flutter_cockpit_devtools/src/mcp/cockpit_mcp_tool.dart';
import 'package:test/test.dart';

void main() {
  test('serveStdio responds to initialize and tools/list over stdio framing',
      () async {
    final input = StreamController<List<int>>();
    final output = _MemoryByteSink();
    final server = CockpitMcpServer(
      tools: <CockpitMcpTool>[
        _FakeCockpitMcpTool(name: 'echo_tool'),
      ],
    );

    unawaited(server.serveStdio(input: input.stream, output: output));

    input.add(
      _frameFor(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': <String, Object?>{
          'protocolVersion': '2025-11-05',
          'capabilities': <String, Object?>{},
          'clientInfo': <String, Object?>{
            'name': 'test client',
            'version': '1.0.0',
          },
        },
      }),
    );
    input.add(
      _frameFor(<String, Object?>{
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      }),
    );
    input.add(
      _frameFor(<String, Object?>{
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/list',
        'params': <String, Object?>{},
      }),
    );
    await input.close();
    await output.done;

    final payloads = _decodeFrames(output.bytes);
    expect(payloads, hasLength(2));
    expect(payloads.first['result'], isA<Map<String, Object?>>());

    final toolsResult = payloads.last['result'] as Map<String, Object?>;
    final tools =
        (toolsResult['tools'] as List<Object?>).cast<Map<String, Object?>>();
    expect(tools.single['name'], 'echo_tool');
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
        'properties': <String, Object?>{},
      };

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> arguments) async {
    return cockpitMcpResult(
      text: 'ok',
      structuredContent: const <String, Object?>{'ok': true},
    );
  }
}

List<int> _frameFor(Map<String, Object?> payload) {
  final body = utf8.encode(jsonEncode(payload));
  return <int>[
    ...ascii.encode('Content-Length: ${body.length}\r\n\r\n'),
    ...body,
  ];
}

List<Map<String, Object?>> _decodeFrames(List<int> bytes) {
  final payloads = <Map<String, Object?>>[];
  var offset = 0;
  while (offset < bytes.length) {
    final headerEnd = _indexOfHeaderTerminator(bytes, offset);
    if (headerEnd == null) {
      break;
    }
    final headerText = ascii.decode(bytes.sublist(offset, headerEnd));
    final contentLength = _readContentLength(headerText);
    final bodyStart = headerEnd + 4;
    final bodyEnd = bodyStart + contentLength;
    payloads.add(
      Map<String, Object?>.from(
        jsonDecode(utf8.decode(bytes.sublist(bodyStart, bodyEnd)))
            as Map<Object?, Object?>,
      ),
    );
    offset = bodyEnd;
  }
  return payloads;
}

int? _indexOfHeaderTerminator(List<int> buffer, int offset) {
  for (var index = offset; index <= buffer.length - 4; index++) {
    if (buffer[index] == 13 &&
        buffer[index + 1] == 10 &&
        buffer[index + 2] == 13 &&
        buffer[index + 3] == 10) {
      return index;
    }
  }
  return null;
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
    return int.parse(line.substring(separator + 1).trim());
  }
  throw StateError('Missing Content-Length header.');
}

final class _MemoryByteSink implements StreamSink<List<int>> {
  final BytesBuilder _builder = BytesBuilder(copy: false);
  final Completer<void> _done = Completer<void>();

  List<int> get bytes => _builder.takeBytes();

  @override
  Future<void> get done => _done.future;

  @override
  void add(List<int> data) {
    _builder.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    if (!_done.isCompleted) {
      _done.completeError(error, stackTrace);
    }
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }
}
