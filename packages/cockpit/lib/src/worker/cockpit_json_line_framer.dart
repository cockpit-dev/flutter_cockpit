import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'cockpit_worker_value_reader.dart';

final class CockpitJsonLineFrameException implements Exception {
  const CockpitJsonLineFrameException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'CockpitJsonLineFrameException($code): $message';
}

final class CockpitJsonLineFramer
    extends StreamTransformerBase<List<int>, Map<String, Object?>> {
  const CockpitJsonLineFramer({
    this.maximumBytes = cockpitWorkerMaximumPayloadBytes,
  });

  final int maximumBytes;

  @override
  Stream<Map<String, Object?>> bind(Stream<List<int>> stream) {
    if (maximumBytes < 1024 ||
        maximumBytes > cockpitWorkerMaximumPayloadBytes) {
      throw ArgumentError.value(maximumBytes, 'maximumBytes');
    }
    late StreamController<Map<String, Object?>> controller;
    StreamSubscription<List<int>>? subscription;
    final bytes = BytesBuilder(copy: false);
    var frameLength = 0;
    var terminated = false;

    void fail(CockpitJsonLineFrameException error) {
      if (terminated) return;
      terminated = true;
      controller.addError(error);
      unawaited(subscription?.cancel());
      unawaited(controller.close());
    }

    void emitFrame() {
      if (frameLength == 0) {
        fail(
          const CockpitJsonLineFrameException(
            'emptyFrame',
            'Worker protocol frames cannot be empty.',
          ),
        );
        return;
      }
      final frame = bytes.takeBytes();
      frameLength = 0;
      try {
        final text = utf8.decode(frame, allowMalformed: false);
        final decoded = jsonDecode(text);
        controller.add(workerObject(decoded, r'$'));
      } on FormatException {
        fail(
          const CockpitJsonLineFrameException(
            'invalidJson',
            'Worker protocol frame is invalid or exceeds JSON bounds.',
          ),
        );
      }
    }

    controller = StreamController<Map<String, Object?>>(
      sync: true,
      onListen: () {
        subscription = stream.listen(
          (chunk) {
            if (terminated) return;
            for (final byte in chunk) {
              if (byte == 0x0A) {
                emitFrame();
                if (terminated) return;
                continue;
              }
              if (byte == 0x0D) {
                fail(
                  const CockpitJsonLineFrameException(
                    'invalidDelimiter',
                    'Worker protocol requires LF frame delimiters.',
                  ),
                );
                return;
              }
              frameLength += 1;
              if (frameLength > maximumBytes) {
                fail(
                  const CockpitJsonLineFrameException(
                    'frameTooLarge',
                    'Worker protocol frame exceeds the payload limit.',
                  ),
                );
                return;
              }
              bytes.addByte(byte);
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!terminated) controller.addError(error, stackTrace);
          },
          onDone: () {
            if (terminated) return;
            if (frameLength != 0) {
              fail(
                const CockpitJsonLineFrameException(
                  'truncatedFrame',
                  'Worker protocol ended with an incomplete frame.',
                ),
              );
              return;
            }
            terminated = true;
            unawaited(controller.close());
          },
          cancelOnError: false,
        );
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }
}
