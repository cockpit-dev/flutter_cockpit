import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_cockpit_devtools/src/infrastructure/cockpit_process_manager.dart';
import 'package:flutter_cockpit/flutter_cockpit.dart';
import 'package:flutter_cockpit_devtools/src/adapters/cockpit_capture_adapter.dart';
import 'package:flutter_cockpit_devtools/src/adapters/cockpit_recording_adapter.dart';
import 'package:flutter_cockpit_devtools/src/system_control/cockpit_system_control_action_service.dart';
import 'package:test/test.dart';

void main() {
  test('android tap executes through adb shell input tap', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.tap,
        parameters: <String, Object?>{'x': 42, 'y': 88},
      ),
    );

    expect(result.success, isTrue);
    expect(result.availability, CockpitSystemControlAvailability.available);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'tap',
      '42',
      '88',
    ]);
    expect(processManager.starts.single.executable, 'adb');
    expect(processManager.starts.single.arguments, <String>[
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'tap',
      '42',
      '88',
    ]);
  });

  test(
    'blocked ios physical action returns guidance without spawning process',
    () async {
      final processManager = _FakeProcessManager();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'ios',
          deviceId: '00008110-001234',
          action: CockpitSystemControlAction.tap,
          parameters: <String, Object?>{'x': 42, 'y': 88},
        ),
      );

      expect(result.success, isFalse);
      expect(result.availability, CockpitSystemControlAvailability.blocked);
      expect(result.recommendedNextStep, 'preferFlutterSemanticPlane');
      expect(
        result.requires,
        contains('developer-signed XCTest/WebDriverAgent runner'),
      );
      expect(processManager.starts, isEmpty);
    },
  );

  test('missing required parameters fail before spawning process', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.tap,
      ),
    );

    expect(result.success, isFalse);
    expect(result.availability, CockpitSystemControlAvailability.available);
    expect(result.errorCode, 'missingSystemActionParameter');
    expect(result.recommendedNextStep, 'fixActionPayload');
    expect(processManager.starts, isEmpty);
  });

  test('android readUiTree cats a dumped XML tree', () async {
    final processManager = _FakeProcessManager();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.readUiTree,
      ),
    );

    expect(result.success, isTrue);
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'sh',
      '-c',
      'uiautomator dump /sdcard/window.xml >/dev/null && cat /sdcard/window.xml && rm /sdcard/window.xml',
    ]);
  });

  test('timed out command returns structured action failure', () async {
    final service = CockpitSystemControlActionService(
      processManager: _HangingProcessManager(),
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.tap,
        parameters: <String, Object?>{'x': 42, 'y': 88},
        timeout: Duration(milliseconds: 1),
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'systemActionTimedOut');
    expect(result.recommendedNextStep, 'inspectShellFailure');
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'tap',
      '42',
      '88',
    ]);
  });

  test('process startup failure returns structured action failure', () async {
    final service = CockpitSystemControlActionService(
      processManager: _ThrowingProcessManager(),
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.pressBack,
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'systemActionProcessFailed');
    expect(result.recommendedNextStep, 'inspectShellFailure');
    expect(result.errorMessage, contains('Unable to start process'));
    expect(result.command, <String>[
      'adb',
      '-s',
      'emulator-5554',
      'shell',
      'input',
      'keyevent',
      'KEYCODE_BACK',
    ]);
  });

  test(
    'captureScreenshot copies adapter artifact to requested output path',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'cockpit_system_capture_test_',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final sourceFile = File('${tempDir.path}/source.png');
      await sourceFile.writeAsBytes(<int>[137, 80, 78, 71]);
      final outputFile = File('${tempDir.path}/copied.png');
      final processManager = _FakeProcessManager();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
        captureAdapterFactory: (_) => _FakeCaptureAdapter(sourceFile),
      );

      final result = await service.run(
        CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.captureScreenshot,
          parameters: <String, Object?>{
            'name': 'acceptance',
            'outputPath': outputFile.path,
          },
        ),
      );

      expect(result.success, isTrue);
      expect(result.sourceFilePath, outputFile.path);
      expect(result.artifact?['relativePath'], 'screenshots/acceptance.png');
      expect(await outputFile.readAsBytes(), <int>[137, 80, 78, 71]);
      expect(processManager.starts, isEmpty);
    },
  );

  test('captureScreenshot adapter failure returns structured result', () async {
    final service = CockpitSystemControlActionService(
      captureAdapterFactory: (_) => const _FailingCaptureAdapter(),
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.captureScreenshot,
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'systemCaptureFailed');
    expect(result.recommendedNextStep, 'inspectCaptureFailure');
    expect(result.errorMessage, contains('capture permission denied'));
  });

  test(
    'startRecording starts adapter session without spawning process',
    () async {
      final processManager = _FakeProcessManager();
      final recordingAdapter = _FakeRecordingAdapter();
      final service = CockpitSystemControlActionService(
        processManager: processManager,
        recordingAdapterFactory: (_) => recordingAdapter,
      );

      final result = await service.run(
        const CockpitSystemControlActionRequest(
          platform: 'android',
          deviceId: 'emulator-5554',
          action: CockpitSystemControlAction.startRecording,
          parameters: <String, Object?>{'name': 'flow', 'purpose': 'repro'},
        ),
      );

      expect(result.success, isTrue);
      expect(result.recommendedNextStep, 'runFlowThenStopRecording');
      expect(result.recordingSession?['state'], 'recording');
      expect(recordingAdapter.startedRequest?.name, 'flow');
      expect(
        recordingAdapter.startedRequest?.purpose,
        CockpitRecordingPurpose.repro,
      );
      expect(processManager.starts, isEmpty);
    },
  );

  test('stopRecording returns completed adapter artifact', () async {
    final processManager = _FakeProcessManager();
    final recordingAdapter = _FakeRecordingAdapter();
    final service = CockpitSystemControlActionService(
      processManager: processManager,
      recordingAdapterFactory: (_) => recordingAdapter,
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.stopRecording,
      ),
    );

    expect(result.success, isTrue);
    expect(result.sourceFilePath, '/tmp/system-recording.mp4');
    expect(result.artifact?['relativePath'], 'recordings/system-recording.mp4');
    expect(result.recordingResult?['state'], 'completed');
    expect(processManager.starts, isEmpty);
  });

  test('stopRecording adapter failure returns structured result', () async {
    final service = CockpitSystemControlActionService(
      recordingAdapterFactory: (_) => const _FailingRecordingAdapter(),
    );

    final result = await service.run(
      const CockpitSystemControlActionRequest(
        platform: 'android',
        deviceId: 'emulator-5554',
        action: CockpitSystemControlAction.stopRecording,
      ),
    );

    expect(result.success, isFalse);
    expect(result.errorCode, 'systemRecordingFailed');
    expect(result.recommendedNextStep, 'inspectRecordingFailure');
    expect(result.errorMessage, contains('No active recording session'));
  });
}

final class _FakeCaptureAdapter implements CockpitCaptureAdapter {
  const _FakeCaptureAdapter(this.sourceFile);

  final File sourceFile;

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) async {
    final request = command.screenshotRequest!;
    final artifact = CockpitArtifactRef(
      role: 'screenshot',
      relativePath: 'screenshots/${request.name}.png',
    );
    return CockpitCommandExecution(
      result: CockpitCommandResult(
        success: true,
        commandId: command.commandId,
        commandType: command.commandType,
        durationMs: 12,
        artifacts: <CockpitArtifactRef>[artifact],
      ),
      artifactSourcePaths: <String, String>{
        artifact.relativePath: sourceFile.path,
      },
    );
  }
}

final class _FailingCaptureAdapter implements CockpitCaptureAdapter {
  const _FailingCaptureAdapter();

  @override
  Future<CockpitCommandExecution> capture(CockpitCommand command) {
    throw StateError('capture permission denied');
  }
}

final class _FakeRecordingAdapter implements CockpitRecordingAdapter {
  CockpitRecordingRequest? startedRequest;

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) async {
    startedRequest = request;
    return CockpitRecordingSession(
      request: request,
      state: CockpitRecordingState.recording,
    );
  }

  @override
  Future<CockpitRecordingResult> stopRecording() async {
    return CockpitRecordingResult(
      state: CockpitRecordingState.completed,
      purpose: CockpitRecordingPurpose.acceptance,
      recordingKind: CockpitRecordingKind.nativeScreen,
      effectiveLayer: CockpitRecordingLayer.system,
      artifact: const CockpitArtifactRef(
        role: 'recording',
        relativePath: 'recordings/system-recording.mp4',
      ),
      durationMs: 1200,
      sourceFilePath: '/tmp/system-recording.mp4',
    );
  }
}

final class _FailingRecordingAdapter implements CockpitRecordingAdapter {
  const _FailingRecordingAdapter();

  @override
  Future<CockpitRecordingSession> startRecording(
    CockpitRecordingRequest request,
  ) {
    throw StateError('Recording could not start.');
  }

  @override
  Future<CockpitRecordingResult> stopRecording() {
    throw StateError('No active recording session exists.');
  }
}

final class _FakeProcessManager implements CockpitProcessManager {
  final starts = <_StartedProcess>[];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    starts.add(
      _StartedProcess(
        executable: executable,
        arguments: List<String>.unmodifiable(arguments),
      ),
    );
    return _FakeManagedProcess();
  }
}

final class _StartedProcess {
  const _StartedProcess({required this.executable, required this.arguments});

  final String executable;
  final List<String> arguments;
}

final class _HangingProcessManager implements CockpitProcessManager {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    return _HangingManagedProcess();
  }
}

final class _ThrowingProcessManager implements CockpitProcessManager {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    throw ProcessException(executable, arguments, 'Unable to start process');
  }
}

final class _FakeManagedProcess implements Process {
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode async => 0;

  @override
  int get pid => 1234;

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    _stdinController.close();
    return true;
  }
}

final class _HangingManagedProcess implements Process {
  final StreamController<List<int>> _stdinController =
      StreamController<List<int>>();
  final Completer<int> _exitCode = Completer<int>();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  int get pid => 5678;

  @override
  IOSink get stdin => IOSink(_stdinController.sink);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exitCode.isCompleted) {
      _exitCode.complete(-9);
    }
    _stdinController.close();
    return true;
  }
}
