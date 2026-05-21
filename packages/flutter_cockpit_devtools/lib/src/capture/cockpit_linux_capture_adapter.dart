import 'dart:async';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';

import '../platform/linux/cockpit_linux_window_target.dart';
import 'cockpit_host_capture_adapter.dart';

final class CockpitLinuxCaptureAdapter implements CockpitHostCaptureAdapter {
  CockpitLinuxCaptureAdapter({
    required String appId,
    int? processId,
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
    CockpitLinuxWindowTargetResolver windowTargetResolver =
        cockpitResolveLinuxWindowTarget,
    Duration timeout = const Duration(seconds: 5),
    Duration activationSettleDelay = const Duration(milliseconds: 250),
  })  : _appId = appId,
        _processId = processId,
        _captureExecutables = List<String>.unmodifiable(captureExecutables),
        _windowActivatorExecutable = windowActivatorExecutable,
        _processRunner = processRunner,
        _tempFileFactory = tempFileFactory,
        _windowTargetResolver = windowTargetResolver,
        _timeout = timeout,
        _activationSettleDelay = activationSettleDelay;

  final String _appId;
  final int? _processId;
  final List<String> _captureExecutables;
  final String? _windowActivatorExecutable;
  final CockpitCaptureProcessRunner _processRunner;
  final CockpitCaptureTempFileFactory _tempFileFactory;
  final CockpitLinuxWindowTargetResolver _windowTargetResolver;
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
      final windowTarget = await _tryResolveWindowTarget();
      await _bestEffortActivate(windowTarget);
      final result = await _capture(outputFile.path, windowTarget);
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

  Future<CockpitLinuxWindowTarget?> _tryResolveWindowTarget() async {
    try {
      return await _windowTargetResolver(
        appId: _appId,
        processId: _processId,
        processRunner: _processRunner,
        timeout: _timeout,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _bestEffortActivate(
    CockpitLinuxWindowTarget? windowTarget,
  ) async {
    final executable = _windowActivatorExecutable;
    if (executable == null || executable.isEmpty) {
      return;
    }
    try {
      final arguments = windowTarget == null
          ? <String>['-xa', _appId]
          : <String>['-ia', windowTarget.windowId];
      final result = await _processRunner(
        executable,
        arguments,
      ).timeout(_timeout);
      if (result.exitCode == 0 && _activationSettleDelay > Duration.zero) {
        await Future<void>.delayed(_activationSettleDelay);
      }
    } on Object {
      // Activation is best-effort only.
    }
  }

  Future<ProcessResult> _capture(
    String outputPath,
    CockpitLinuxWindowTarget? windowTarget,
  ) async {
    Object? lastFailure;
    for (final executable in _captureExecutables) {
      try {
        final arguments = _captureArgumentsFor(
          executable,
          outputPath,
          windowTarget,
        );
        if (arguments == null) {
          lastFailure = StateError(
            '$executable requires a resolved Linux window target for $_appId.',
          );
          continue;
        }
        final result = await _processRunner(
          executable,
          arguments,
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

  List<String>? _captureArgumentsFor(
    String executable,
    String outputPath,
    CockpitLinuxWindowTarget? windowTarget,
  ) {
    return switch (executable) {
      'gnome-screenshot' => <String>['-w', '-f', outputPath],
      'grim' => windowTarget == null
          ? null
          : <String>[
              '-g',
              '${windowTarget.left},${windowTarget.top} ${windowTarget.width}x${windowTarget.height}',
              outputPath,
            ],
      'scrot' => <String>['-u', outputPath],
      'import' => windowTarget == null
          ? null
          : <String>['-window', windowTarget.windowId, outputPath],
      _ => <String>[outputPath],
    };
  }
}
