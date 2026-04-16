import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/flutter_cockpit_devtools.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test(
    'simctl adapter accepts a running recorder even when no startup banner is emitted',
    () async {
      const deviceId = 'simulator-no-banner';
      await _deletePersistedSession(deviceId);
      addTearDown(() => _deletePersistedSession(deviceId));

      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_simctl_recording_no_banner',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final runtime = _FakeSimctlRuntime(
        pid: 4101,
        onStop: (outputPath) async {
          File(outputPath).writeAsStringSync('simctl-video-no-banner');
        },
      );

      final adapter = CockpitSimctlRecordingAdapter(
        deviceId: deviceId,
        processStarter: runtime.start,
        pidSignalSender: runtime.sendSignal,
        pidLivenessChecker: runtime.isRunning,
        tempFileFactory: (basename) async =>
            File(p.join(tempDir.path, basename)),
        processRunner: _ffprobeUnavailable,
        startupTimeout: const Duration(seconds: 1),
        finalizationPollInterval: const Duration(milliseconds: 10),
      );

      final session = await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-simctl-no-banner',
          attachToStep: true,
        ),
      );
      final result = await adapter.stopRecording();

      expect(session.state, CockpitRecordingState.recording);
      expect(
        result.state,
        CockpitRecordingState.completed,
        reason: result.failureReason,
      );
      expect(
        File(result.sourceFilePath!).readAsStringSync(),
        'simctl-video-no-banner',
      );
    },
  );

  test(
    'simctl adapter fails when the recording output file is missing',
    () async {
      const deviceId = 'simulator-456';
      await _deletePersistedSession(deviceId);
      addTearDown(() => _deletePersistedSession(deviceId));

      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_simctl_recording_missing_output',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final runtime = _FakeSimctlRuntime(
        pid: 4201,
        startupLine: 'Recording started',
      );

      final adapter = CockpitSimctlRecordingAdapter(
        deviceId: deviceId,
        processStarter: runtime.start,
        pidSignalSender: runtime.sendSignal,
        pidLivenessChecker: runtime.isRunning,
        tempFileFactory: (basename) async =>
            File(p.join(tempDir.path, basename)),
        processRunner: _ffprobeUnavailable,
        finalizationPollInterval: const Duration(milliseconds: 10),
      );

      await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-simctl-missing',
          attachToStep: true,
        ),
      );
      final result = await adapter.stopRecording();

      expect(result.state, CockpitRecordingState.failed);
      expect(result.failureReason, contains('output'));
    },
  );

  test(
    'simctl adapter accepts sparse simulator recordings when ffprobe reports a usable timeline',
    () async {
      const deviceId = 'simulator-321';
      await _deletePersistedSession(deviceId);
      addTearDown(() => _deletePersistedSession(deviceId));

      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_simctl_recording_sparse_timeline',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final runtime = _FakeSimctlRuntime(
        pid: 4301,
        startupLine: 'Recording started',
        onStop: (outputPath) async {
          File(outputPath).writeAsStringSync('simctl-video');
        },
      );

      final adapter = CockpitSimctlRecordingAdapter(
        deviceId: deviceId,
        processStarter: runtime.start,
        pidSignalSender: runtime.sendSignal,
        pidLivenessChecker: runtime.isRunning,
        tempFileFactory: (basename) async =>
            File(p.join(tempDir.path, basename)),
        processRunner: (executable, arguments) async {
          if (executable == 'ffprobe') {
            return ProcessResult(
                0,
                0,
                '''
{"format":{"duration":"2.706"},"streams":[{"codec_type":"video","nb_frames":"44"}]}
''',
                '');
          }
          throw ProcessException(executable, arguments, 'unexpected command');
        },
        finalizationPollInterval: const Duration(milliseconds: 10),
      );

      await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-simctl-sparse',
          attachToStep: true,
        ),
      );
      final result = await adapter.stopRecording();

      expect(
        result.state,
        CockpitRecordingState.completed,
        reason: result.failureReason,
      );
    },
  );
}

Future<ProcessResult> _ffprobeUnavailable(
  String executable,
  List<String> arguments,
) async {
  if (executable == 'ffprobe') {
    return ProcessResult(0, 1, '', 'ffprobe unavailable');
  }
  throw ProcessException(executable, arguments, 'unexpected command');
}

Future<void> _deletePersistedSession(String deviceId) async {
  final sanitizedDeviceId =
      deviceId.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'flutter_cockpit_recording_sessions${Platform.pathSeparator}'
    'simctl_$sanitizedDeviceId.json',
  );
  if (file.existsSync()) {
    await file.delete();
  }
}

final class _FakeSimctlRuntime {
  _FakeSimctlRuntime({
    required this.pid,
    this.startupLine,
    this.onStop,
  }) : _process = _FakeSimctlProcess(
          pid: pid,
          startupLine: startupLine,
        );

  final int pid;
  final String? startupLine;
  final Future<void> Function(String outputPath)? onStop;
  final _FakeSimctlProcess _process;
  bool _running = true;
  String? _outputPath;

  Future<Process> start(String executable, List<String> arguments) async {
    _outputPath = arguments.last;
    return _process;
  }

  bool sendSignal(int targetPid, ProcessSignal signal) {
    if (targetPid != pid || !_running) {
      return false;
    }
    if (signal == ProcessSignal.sigint &&
        _outputPath != null &&
        onStop != null) {
      unawaited(onStop!(_outputPath!).then((_) => _stop()));
      return true;
    }
    unawaited(_stop());
    return true;
  }

  Future<bool> isRunning(int targetPid) async {
    return targetPid == pid && _running;
  }

  Future<void> _stop() async {
    _running = false;
    await _process.closeWithExitCode(0);
  }
}

final class _FakeSimctlProcess implements Process {
  _FakeSimctlProcess({
    required this.pid,
    this.startupLine,
  }) {
    if (startupLine != null) {
      scheduleMicrotask(() {
        if (!_stderrController.isClosed) {
          _stderrController.add(utf8.encode('$startupLine\n'));
        }
      });
    }
  }

  @override
  final int pid;

  final String? startupLine;
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  final Completer<int> _exitCodeCompleter = Completer<int>();

  late final IOSink _stdin = IOSink(_stdinController.sink);

  @override
  IOSink get stdin => _stdin;

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    unawaited(closeWithExitCode(0));
    return true;
  }

  Future<void> closeWithExitCode(int code) async {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
    await _stdoutController.close();
    await _stderrController.close();
    await _stdinController.close();
  }
}
