import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit_protocol/flutter_cockpit_protocol.dart';

import '../infrastructure/cockpit_process_output_collector.dart';
import 'cockpit_host_capture_adapter.dart';

final class CockpitAdbCaptureAdapter implements CockpitHostCaptureAdapter {
  CockpitAdbCaptureAdapter({
    required String deviceId,
    String executable = 'adb',
    CockpitCaptureProcessStarter processStarter = Process.start,
    CockpitCaptureTempFileFactory tempFileFactory =
        cockpitCreateCaptureTempFile,
    Duration timeout = const Duration(seconds: 5),
  }) : _deviceId = deviceId,
       _executable = executable,
       _processStarter = processStarter,
       _tempFileFactory = tempFileFactory,
       _timeout = timeout;

  final String _deviceId;
  final String _executable;
  final CockpitCaptureProcessStarter _processStarter;
  final CockpitCaptureTempFileFactory _tempFileFactory;
  final Duration _timeout;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    final request = command.screenshotRequest;
    if (request == null) {
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: 0,
        message: 'Host screenshot capture requires a screenshot request.',
      );
    }

    final stopwatch = Stopwatch()..start();
    final artifact = cockpitCaptureArtifactForRequest(request);
    final outputFile = await _tempFileFactory(
      cockpitCaptureFileName(request.name),
    );
    outputFile.parent.createSync(recursive: true);
    if (outputFile.existsSync()) {
      outputFile.deleteSync();
    }

    final process = await _processStarter(_executable, <String>[
      '-s',
      _deviceId,
      'exec-out',
      'screencap',
      '-p',
    ]);
    final sink = outputFile.openWrite();
    final stdoutDone = Completer<void>();
    var lastStdoutDataAt = DateTime.now();
    final stdoutSubscription = process.stdout.listen(
      (chunk) {
        lastStdoutDataAt = DateTime.now();
        sink.add(chunk);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!stdoutDone.isCompleted) {
          stdoutDone.completeError(error, stackTrace);
        }
      },
      onDone: () {
        if (!stdoutDone.isCompleted) {
          stdoutDone.complete();
        }
      },
      cancelOnError: true,
    );
    final stderrCollector = CockpitProcessOutputCollector(process.stderr);

    try {
      final exitCode = await process.exitCode.timeout(_timeout);
      await _waitForCaptureStream(stdoutDone.future, () => lastStdoutDataAt);
      await _cancelCaptureSubscription(stdoutSubscription);
      final stderr = await stderrCollector.collectText();
      await _closeCaptureSink(sink);
      stopwatch.stop();

      if (exitCode != 0) {
        return cockpitFailedCaptureExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'adb screencap failed.',
          details: <String, Object?>{
            'deviceId': _deviceId,
            'exitCode': exitCode,
            'stderr': stderr.trim(),
          },
        );
      }
      return cockpitValidateHostCaptureOutput(
        command: command,
        artifact: artifact,
        durationMs: stopwatch.elapsedMilliseconds,
        outputFile: outputFile,
        captureDescription: 'adb screencap',
        details: <String, Object?>{'deviceId': _deviceId},
      );
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await _cancelCaptureSubscription(stdoutSubscription);
      await stderrCollector.cancel();
      await _closeCaptureSink(sink);
      stopwatch.stop();
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        message: 'adb screencap timed out.',
        details: <String, Object?>{'deviceId': _deviceId},
      );
    } on Object catch (error) {
      process.kill(ProcessSignal.sigkill);
      await _cancelCaptureSubscription(stdoutSubscription);
      await stderrCollector.cancel();
      await _closeCaptureSink(sink);
      stopwatch.stop();
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        message: 'adb screencap threw an unexpected error.',
        details: <String, Object?>{
          'deviceId': _deviceId,
          'error': error.toString(),
        },
      );
    }
  }
}

// Drain pending stdout after process exit: keep reading while data is still
// arriving (slow pipe must not truncate the PNG) but return quickly once the
// pipe goes quiet, because an inherited stdout handle never closes.
Future<void> _waitForCaptureStream(
  Future<void> done,
  DateTime Function() lastDataAt,
) async {
  const maxDrain = Duration(seconds: 2);
  const quietWindow = Duration(milliseconds: 150);
  final deadline = DateTime.now().add(maxDrain);
  var isDone = false;
  Object? streamError;
  StackTrace? streamStackTrace;
  unawaited(
    done.then(
      (_) => isDone = true,
      onError: (Object error, StackTrace stackTrace) {
        streamError = error;
        streamStackTrace = stackTrace;
        isDone = true;
      },
    ),
  );
  while (!isDone && DateTime.now().isBefore(deadline)) {
    if (DateTime.now().difference(lastDataAt()) >= quietWindow) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
  // A mid-stream read error means the PNG may be truncated; surface it so the
  // capture reports failure instead of shipping a corrupt artifact as success.
  if (streamError != null) {
    Error.throwWithStackTrace(
      streamError!,
      streamStackTrace ?? StackTrace.current,
    );
  }
}

Future<void> _cancelCaptureSubscription(
  StreamSubscription<List<int>> subscription,
) async {
  try {
    await subscription.cancel().timeout(const Duration(milliseconds: 200));
  } on Object {
    // Best-effort process stream cleanup only.
  }
}

Future<void> _closeCaptureSink(IOSink sink) async {
  try {
    await sink.flush().timeout(const Duration(milliseconds: 200));
  } on Object {
    // The failure result below is more useful than a sink cleanup error.
  }
  try {
    await sink.close().timeout(const Duration(milliseconds: 200));
  } on Object {
    // The temp file may already be closed after a stream error.
  }
}
