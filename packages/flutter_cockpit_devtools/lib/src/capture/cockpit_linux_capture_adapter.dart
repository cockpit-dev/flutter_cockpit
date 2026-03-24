import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import 'cockpit_host_capture_adapter.dart';

final class CockpitLinuxCaptureAdapter implements CockpitHostCaptureAdapter {
  CockpitLinuxCaptureAdapter({
    required String appId,
    List<String> captureExecutables = const <String>[
      'gnome-screenshot',
      'grim',
      'scrot',
      'import',
    ],
    String? windowActivatorExecutable = 'wmctrl',
    CockpitCaptureProcessRunner processRunner = Process.run,
    CockpitCaptureTempFileFactory tempFileFactory =
        cockpitCreateCaptureTempFile,
    Duration timeout = const Duration(seconds: 5),
    Duration activationSettleDelay = const Duration(milliseconds: 250),
  })  : _appId = appId,
        _captureExecutables = List<String>.unmodifiable(captureExecutables),
        _windowActivatorExecutable = windowActivatorExecutable,
        _processRunner = processRunner,
        _tempFileFactory = tempFileFactory,
        _timeout = timeout,
        _activationSettleDelay = activationSettleDelay;

  final String _appId;
  final List<String> _captureExecutables;
  final String? _windowActivatorExecutable;
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
      await _bestEffortActivate();
      final result = await _capture(outputFile.path);
      stopwatch.stop();

      if (result.exitCode != 0) {
        return cockpitFailedCaptureExecution(
          command: command,
          durationMs: stopwatch.elapsedMilliseconds,
          message: 'Linux host screenshot failed.',
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
          message: 'Linux host screenshot produced an empty PNG artifact.',
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
        message: 'Linux host screenshot timed out.',
        details: <String, Object?>{'appId': _appId},
      );
    } on StateError catch (error) {
      stopwatch.stop();
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        message: 'Linux host screenshot failed.',
        details: <String, Object?>{
          'appId': _appId,
          'error': error.toString(),
        },
      );
    } on Object catch (error) {
      stopwatch.stop();
      return cockpitFailedCaptureExecution(
        command: command,
        durationMs: stopwatch.elapsedMilliseconds,
        message: 'Linux host screenshot threw an unexpected error.',
        details: <String, Object?>{
          'appId': _appId,
          'error': error.toString(),
        },
      );
    }
  }

  Future<void> _bestEffortActivate() async {
    final executable = _windowActivatorExecutable;
    if (executable == null || executable.isEmpty) {
      return;
    }
    try {
      final result = await _processRunner(
        executable,
        <String>['-xa', _appId],
      ).timeout(_timeout);
      if (result.exitCode == 0 && _activationSettleDelay > Duration.zero) {
        await Future<void>.delayed(_activationSettleDelay);
      }
    } on Object {
      // Activation is best-effort only.
    }
  }

  Future<ProcessResult> _capture(String outputPath) async {
    Object? lastFailure;
    for (final executable in _captureExecutables) {
      try {
        final result = await _processRunner(
          executable,
          _captureArgumentsFor(executable, outputPath),
        ).timeout(_timeout);
        if (result.exitCode == 0) {
          return result;
        }
        lastFailure = StateError(
          '$executable exited with ${result.exitCode}: ${result.stderr ?? result.stdout}',
        );
      } on ProcessException catch (error) {
        lastFailure = error;
      }
    }
    throw StateError(
      lastFailure?.toString() ??
          'No Linux screenshot executable succeeded for $_appId.',
    );
  }

  List<String> _captureArgumentsFor(String executable, String outputPath) {
    return switch (executable) {
      'gnome-screenshot' => <String>['-f', outputPath],
      'grim' => <String>[outputPath],
      'scrot' => <String>[outputPath],
      'import' => <String>['-window', 'root', outputPath],
      _ => <String>[outputPath],
    };
  }
}
