import 'dart:async';
import 'dart:convert';

import 'package:stream_channel/stream_channel.dart';

StreamChannel<String> cockpitLspChannel(
  Stream<List<int>> stream,
  StreamSink<List<int>> sink,
) {
  final parser = _CockpitLspParser(stream);
  final output = _CockpitLspOutputSink(sink: sink, onClose: parser.close);
  return StreamChannel.withGuarantees(parser.stream, output);
}

void _serializeLspMessage(String data, EventSink<List<int>> sink) {
  final message = utf8.encode(data);
  final header = 'Content-Length: ${message.length}\r\n\r\n';
  sink.add(ascii.encode(header));
  sink.add(message);
}

final class _CockpitLspParser {
  _CockpitLspParser(Stream<List<int>> input)
    : _subscription = input.expand((chunk) => chunk).listen(null) {
    _subscription
      ..onData(_handleByte)
      ..onDone(_controller.close);
  }

  final _controller = StreamController<String>();
  final List<int> _buffer = <int>[];
  late final StreamSubscription<int> _subscription;
  bool _readingHeader = true;
  int _contentLength = -1;

  Stream<String> get stream => _controller.stream;

  Future<void> close() => _subscription.cancel();

  void _handleByte(int byte) {
    _buffer.add(byte);
    if (_readingHeader && _headerComplete) {
      _contentLength = _parseContentLength();
      _buffer.clear();
      _readingHeader = false;
      return;
    }
    if (!_readingHeader && _buffer.length >= _contentLength) {
      _controller.add(utf8.decode(_buffer));
      _buffer.clear();
      _readingHeader = true;
      _contentLength = -1;
    }
  }

  bool get _headerComplete {
    final length = _buffer.length;
    return length >= 4 &&
        _buffer[length - 4] == 13 &&
        _buffer[length - 3] == 10 &&
        _buffer[length - 2] == 13 &&
        _buffer[length - 1] == 10;
  }

  int _parseContentLength() {
    final header = ascii.decode(_buffer);
    final lines = header.split('\r\n');
    final lengthLine = lines.firstWhere(
      (line) => line.startsWith('Content-Length:'),
      orElse: () => '',
    );
    if (lengthLine.isEmpty) {
      throw const FormatException('Missing Content-Length header.');
    }
    return int.parse(lengthLine.split(':').last.trim());
  }
}

final class _CockpitLspOutputSink implements StreamSink<String> {
  _CockpitLspOutputSink({
    required StreamSink<List<int>> sink,
    required Future<void> Function() onClose,
  }) : _sink = sink,
       _onClose = onClose;

  final StreamSink<List<int>> _sink;
  final Future<void> Function() _onClose;

  @override
  void add(String data) => _serializeLspMessage(data, _sink);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _sink.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<String> stream) async {
    await for (final event in stream) {
      add(event);
    }
  }

  @override
  Future<void> close() async {
    await _sink.close();
    await _onClose();
  }

  @override
  Future<void> get done => _sink.done;
}
