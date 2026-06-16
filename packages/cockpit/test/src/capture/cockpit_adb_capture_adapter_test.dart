import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:cockpit/src/capture/cockpit_adb_capture_adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'adb capture returns after process exit when stdout remains inherited',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_adb_capture_adapter',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final process = _OpenStdoutProcess(
        stdoutPayload: 'png-data',
        exitCode: Future<int>.value(0),
      );
      addTearDown(process.close);
      final adapter = CockpitAdbCaptureAdapter(
        deviceId: 'emulator-5554',
        processStarter: (_, _) async => process,
        tempFileFactory: (basename) async =>
            File(p.join(tempDir.path, basename)),
        timeout: const Duration(seconds: 2),
      );

      final execution = await adapter
          .capture(_captureCommand())
          .timeout(const Duration(milliseconds: 500));

      expect(execution.result.success, isTrue);
      final sourcePath = execution.artifactSourcePaths.values.single;
      expect(File(sourcePath).readAsStringSync(), 'png-data');
    },
  );

  test('adb capture timeout is not blocked by open stdout', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'cockpit_adb_capture_adapter_timeout',
    );
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final process = _OpenStdoutProcess(
      stdoutPayload: '',
      exitCode: Completer<int>().future,
    );
    addTearDown(process.close);
    final adapter = CockpitAdbCaptureAdapter(
      deviceId: 'emulator-5554',
      processStarter: (_, _) async => process,
      tempFileFactory: (basename) async => File(p.join(tempDir.path, basename)),
      timeout: const Duration(milliseconds: 20),
    );

    final execution = await adapter
        .capture(_captureCommand())
        .timeout(const Duration(milliseconds: 500));

    expect(execution.result.success, isFalse);
    expect(execution.result.error?.message, 'adb screencap timed out.');
    expect(process.killSignals, contains(ProcessSignal.sigkill));
  });
}

CockpitCommand _captureCommand() => CockpitCommand(
  commandId: 'capture-adb',
  commandType: CockpitCommandType.captureScreenshot,
  screenshotRequest: const CockpitScreenshotRequest(
    reason: CockpitScreenshotReason.acceptance,
    name: 'adb-acceptance',
  ),
);

final class _OpenStdoutProcess implements Process {
  _OpenStdoutProcess({
    required String stdoutPayload,
    required Future<int> exitCode,
  }) : _exitCode = exitCode {
    scheduleMicrotask(() {
      if (stdoutPayload.isNotEmpty) {
        _stdoutController.add(utf8.encode(stdoutPayload));
      }
    });
  }

  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  final Future<int> _exitCode;
  final List<ProcessSignal> killSignals = <ProcessSignal>[];

  @override
  Future<int> get exitCode => _exitCode;

  @override
  int get pid => 1;

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killSignals.add(signal);
    return true;
  }

  Future<void> close() async {
    if (!_stdoutController.isClosed) {
      unawaited(_stdoutController.close());
    }
    if (!_stderrController.isClosed) {
      unawaited(_stderrController.close());
    }
    if (!_stdinController.isClosed) {
      unawaited(_stdinController.close());
    }
  }
}
