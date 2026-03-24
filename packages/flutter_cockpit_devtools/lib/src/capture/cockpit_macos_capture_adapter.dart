import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_host_capture_adapter.dart';

final class CockpitMacosCaptureAdapter implements CockpitHostCaptureAdapter {
  CockpitMacosCaptureAdapter({
    required String appId,
    String osascriptExecutable = 'osascript',
    String screencaptureExecutable = 'screencapture',
    CockpitCaptureProcessRunner processRunner = Process.run,
    CockpitCaptureTempFileFactory tempFileFactory =
        cockpitCreateCaptureTempFile,
    Duration timeout = const Duration(seconds: 5),
    Duration activationSettleDelay = const Duration(milliseconds: 250),
  })  : _appId = appId,
        _osascriptExecutable = osascriptExecutable,
        _screencaptureExecutable = screencaptureExecutable,
        _processRunner = processRunner,
        _tempFileFactory = tempFileFactory,
        _timeout = timeout,
        _activationSettleDelay = activationSettleDelay;

  final String _appId;
  final String _osascriptExecutable;
  final String _screencaptureExecutable;
  final CockpitCaptureProcessRunner _processRunner;
  final CockpitCaptureTempFileFactory _tempFileFactory;
  final Duration _timeout;
  final Duration _activationSettleDelay;

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

    try {
      await _activateApp();
      if (_activationSettleDelay > Duration.zero) {
        await Future<void>.delayed(_activationSettleDelay);
      }
      final result = await _processRunner(
        _screencaptureExecutable,
        <String>['-x', '-o', outputFile.path],
      ).timeout(_timeout);
      stopwatch.stop();

      if (result.exitCode != 0) {
        return cockpitFailedCaptureExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'macOS screencapture failed.',
          details: <String, Object?>{
            'appId': _appId,
            'exitCode': result.exitCode,
            'stderr': '${result.stderr}'.trim(),
          },
        );
      }
      if (!outputFile.existsSync() || outputFile.lengthSync() == 0) {
        return cockpitFailedCaptureExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'macOS screencapture produced an empty PNG artifact.',
          details: <String, Object?>{'appId': _appId},
        );
      }

      return cockpitSuccessfulHostCaptureExecution(
        command: command,
        artifact: artifact,
        durationMs: stopwatch.elapsedMilliseconds,
        sourceFilePath: outputFile.path,
      );
    } on TimeoutException {
      stopwatch.stop();
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        message: 'macOS screencapture timed out.',
        details: <String, Object?>{'appId': _appId},
      );
    } on Object catch (error) {
      stopwatch.stop();
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        message: 'macOS screencapture threw an unexpected error.',
        details: <String, Object?>{
          'appId': _appId,
          'error': error.toString(),
        },
      );
    }
  }

  Future<void> _activateApp() async {
    final result = await _processRunner(_osascriptExecutable, <String>[
      '-e',
      'tell application id "$_appId" to activate',
    ]);
    if (result.exitCode != 0) {
      throw StateError(
        'Unable to activate macOS app $_appId: ${result.stderr ?? result.stdout}',
      );
    }
  }
}
