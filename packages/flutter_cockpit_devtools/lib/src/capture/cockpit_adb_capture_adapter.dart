import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_host_capture_adapter.dart';

final class CockpitAdbCaptureAdapter implements CockpitHostCaptureAdapter {
  CockpitAdbCaptureAdapter({
    required String deviceId,
    String executable = 'adb',
    CockpitCaptureProcessStarter processStarter = Process.start,
    CockpitCaptureTempFileFactory tempFileFactory =
        cockpitCreateCaptureTempFile,
    Duration timeout = const Duration(seconds: 5),
  })  : _deviceId = deviceId,
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
    final stderr = StringBuffer();

    try {
      await process.stdout.pipe(sink);
      stderr.write(
        await process.stderr.transform(SystemEncoding().decoder).join(),
      );
      final exitCode = await process.exitCode.timeout(_timeout);
      await sink.flush();
      await sink.close();
      stopwatch.stop();

      if (exitCode != 0) {
        return cockpitFailedCaptureExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'adb screencap failed.',
          details: <String, Object?>{
            'deviceId': _deviceId,
            'exitCode': exitCode,
            'stderr': stderr.toString().trim(),
          },
        );
      }
      if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
        return cockpitFailedCaptureExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'adb screencap produced an empty PNG artifact.',
          details: <String, Object?>{'deviceId': _deviceId},
        );
      }

      return cockpitSuccessfulHostCaptureExecution(
        command: command,
        artifact: artifact,
        durationMs: stopwatch.elapsedMilliseconds,
        sourceFilePath: outputFile.path,
      );
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      await sink.close();
      stopwatch.stop();
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        message: 'adb screencap timed out.',
        details: <String, Object?>{'deviceId': _deviceId},
      );
    } on Object catch (error) {
      process.kill(ProcessSignal.sigkill);
      await sink.close();
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
