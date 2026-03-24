import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/recording/cockpit_windows_recording_adapter.dart';
import 'package:test/test.dart';

void main() {
  test(
    'windows recording adapter starts and finalizes a host recording artifact',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_windows_recording_adapter',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final ffmpegInvocations = <List<String>>[];
      final activationInvocations = <List<String>>[];

      final adapter = CockpitWindowsRecordingAdapter(
        appId: 'cockpit_demo',
        ffmpegExecutable: 'ffmpeg',
        powershellExecutable: 'powershell',
        processStarter: (executable, arguments) async {
          expect(executable, 'ffmpeg');
          ffmpegInvocations.add(List<String>.from(arguments));
          final outputPath = arguments.last;
          return _FakeRecordingProcess(
            startupLine: 'Press [q] to stop',
            onStopRequested: () async {
              File(outputPath).writeAsStringSync('windows-video');
            },
          );
        },
        processRunner: (executable, arguments) async {
          activationInvocations.add(<String>[executable, ...arguments]);
          return ProcessResult(0, 0, '', '');
        },
        startupTimeout: const Duration(seconds: 2),
        stopTimeout: const Duration(seconds: 2),
        finalizationPollInterval: const Duration(milliseconds: 10),
        ffprobeProcessRunner: (executable, arguments) async => ProcessResult(
          0,
          0,
          '{"format":{"duration":"2.000"},"streams":[{"codec_type":"video","nb_frames":"40"}]}',
          '',
        ),
      );

      final session = await adapter.startRecording(
        const CockpitRecordingRequest(
          purpose: CockpitRecordingPurpose.acceptance,
          name: 'host-windows-demo',
          attachToStep: true,
        ),
      );
      final result = await adapter.stopRecording();

      expect(session.state, CockpitRecordingState.recording);
      expect(result.state, CockpitRecordingState.completed);
      expect(
        result.artifact,
        const CockpitArtifactRef(
          role: 'recording',
          relativePath: 'recordings/host-windows-demo.mp4',
        ),
      );
      expect(File(result.sourceFilePath!).readAsStringSync(), 'windows-video');
      expect(ffmpegInvocations.single.join(' '), contains('-f gdigrab'));
      expect(ffmpegInvocations.single.join(' '), contains('-i desktop'));
      expect(activationInvocations.single.first, 'powershell');
    },
  );
}

final class _FakeRecordingProcess implements Process {
  _FakeRecordingProcess({
    required String startupLine,
    required Future<void> Function() onStopRequested,
  }) : _onStopRequested = onStopRequested {
    scheduleMicrotask(() {
      if (!_stderrController.isClosed) {
        _stderrController.add(utf8.encode('$startupLine\n'));
      }
    });
    _stdinController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) async {
      if (line == 'q' && !_exitCodeCompleter.isCompleted) {
        await _onStopRequested();
        await _closeWithExitCode(0);
      }
    });
  }

  final Future<void> Function() _onStopRequested;
  final StreamController<List<int>> _stdoutController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stderrController =
      StreamController<List<int>>();
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  final Completer<int> _exitCodeCompleter = Completer<int>();

  late final IOSink _stdin = IOSink(_stdinController.sink);

  @override
  int get pid => 4242;

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
    if (!_exitCodeCompleter.isCompleted) {
      unawaited(_closeWithExitCode(0));
    }
    return true;
  }

  Future<void> _closeWithExitCode(int code) async {
    if (!_exitCodeCompleter.isCompleted) {
      _exitCodeCompleter.complete(code);
    }
    await _stdoutController.close();
    await _stderrController.close();
  }
}
