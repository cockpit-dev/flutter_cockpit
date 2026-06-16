import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final class CockpitProcessOutputCollector {
  CockpitProcessOutputCollector(
    Stream<List<int>> stream, {
    this.maxBytes = 4 * 1024 * 1024,
  }) {
    _subscription = stream.listen(
      _addChunk,
      onError: (Object error, StackTrace stackTrace) {
        _completeDone();
      },
      onDone: _completeDone,
      cancelOnError: false,
    );
  }

  final int maxBytes;
  final Queue<List<int>> _chunks = Queue<List<int>>();
  final Completer<void> _done = Completer<void>();
  late final StreamSubscription<List<int>> _subscription;
  int _length = 0;
  int _discardedBytes = 0;
  bool _cancelled = false;

  List<int> snapshotBytes() {
    final builder = BytesBuilder(copy: false);
    if (_discardedBytes > 0) {
      builder.add(
        utf8.encode(
          '[flutter_cockpit output truncated: kept last $maxBytes bytes, '
          'discarded $_discardedBytes bytes]\n',
        ),
      );
    }
    for (final chunk in _chunks) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  String snapshotText() => cockpitDecodeProcessOutput(snapshotBytes());

  Future<List<int>> collectBytes({
    Duration grace = const Duration(milliseconds: 200),
  }) async {
    await _waitForDone(grace);
    final bytes = snapshotBytes();
    await cancel();
    return bytes;
  }

  Future<String> collectText({
    Duration grace = const Duration(milliseconds: 200),
  }) async {
    return cockpitDecodeProcessOutput(await collectBytes(grace: grace));
  }

  Future<void> cancel() async {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    try {
      await _subscription.cancel().timeout(const Duration(milliseconds: 200));
    } on Object {
      // Output collection is diagnostic; it must not keep commands alive.
    } finally {
      _completeDone();
    }
  }

  Future<void> _waitForDone(Duration grace) async {
    try {
      await _done.future.timeout(grace);
    } on Object {
      // Child processes may inherit stdout/stderr after the command exits.
      // Return the bytes already captured instead of blocking the agent.
    }
  }

  void _addChunk(List<int> chunk) {
    if (chunk.isEmpty) {
      return;
    }
    if (maxBytes <= 0) {
      _discardedBytes += chunk.length;
      return;
    }
    if (chunk.length >= maxBytes) {
      _discardedBytes += _length + chunk.length - maxBytes;
      _chunks
        ..clear()
        ..add(List<int>.unmodifiable(chunk.sublist(chunk.length - maxBytes)));
      _length = maxBytes;
      return;
    }

    _chunks.add(List<int>.unmodifiable(chunk));
    _length += chunk.length;
    _trimToMaxBytes();
  }

  void _trimToMaxBytes() {
    while (_length > maxBytes && _chunks.isNotEmpty) {
      final excess = _length - maxBytes;
      final first = _chunks.removeFirst();
      if (first.length <= excess) {
        _discardedBytes += first.length;
        _length -= first.length;
        continue;
      }
      _chunks.addFirst(List<int>.unmodifiable(first.sublist(excess)));
      _discardedBytes += excess;
      _length -= excess;
    }
  }

  void _completeDone() {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }
}

String cockpitDecodeProcessOutput(List<int> bytes) {
  try {
    return systemEncoding.decode(bytes);
  } on FormatException {
    return utf8.decode(bytes, allowMalformed: true);
  }
}
