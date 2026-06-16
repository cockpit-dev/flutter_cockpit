import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

StreamChannel<String> cockpitMcpStdioChannel({
  required Stream<List<int>> input,
  required StreamSink<List<int>> output,
}) {
  return StreamChannel.withCloseGuarantee(
    const _CockpitMcpStdioDecoder().bind(input),
    _CockpitMcpStdioSink(output),
  );
}

List<int> _frameMessage(String message) {
  final body = utf8.encode(message);
  return <int>[
    ...ascii.encode('Content-Length: ${body.length}\r\n\r\n'),
    ...body,
  ];
}

final class _CockpitMcpStdioDecoder
    extends StreamTransformerBase<List<int>, String> {
  const _CockpitMcpStdioDecoder();

  @override
  Stream<String> bind(Stream<List<int>> stream) async* {
    var buffer = <int>[];

    await for (final chunk in stream) {
      buffer.addAll(chunk);

      while (true) {
        final headerEnd = _indexOfHeaderTerminator(buffer);
        if (headerEnd == null) {
          break;
        }

        final headerText = ascii.decode(buffer.sublist(0, headerEnd));
        final contentLength = _readContentLength(headerText);
        final bodyStart = headerEnd + 4;
        final bodyEnd = bodyStart + contentLength;
        if (buffer.length < bodyEnd) {
          break;
        }

        yield utf8.decode(buffer.sublist(bodyStart, bodyEnd));
        buffer = buffer.sublist(bodyEnd);
      }
    }

    if (buffer.isNotEmpty) {
      throw const FormatException(
        'Unexpected trailing bytes in MCP stdio stream.',
      );
    }
  }

  int? _indexOfHeaderTerminator(List<int> buffer) {
    for (var index = 0; index <= buffer.length - 4; index++) {
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

    throw const FormatException('Missing Content-Length header.');
  }
}

final class _CockpitMcpStdioSink implements StreamSink<String> {
  _CockpitMcpStdioSink(this._inner);

  final StreamSink<List<int>> _inner;

  @override
  void add(String data) {
    _inner.add(_frameMessage(data));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _inner.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<String> stream) {
    return _inner.addStream(stream.map(_frameMessage));
  }

  @override
  Future<void> close() {
    return _inner.close();
  }

  @override
  Future<void> get done => _inner.done;
}
